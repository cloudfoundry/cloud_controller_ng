require 'spec_helper'

module VCAP::CloudController
  describe ServiceInstanceBindingManager do
    let(:manager) { ServiceInstanceBindingManager.new(event_repository, access_validator, logger) }
    let(:event_repository) { double(:event_repository) }
    let(:access_validator) { double(:access_validator) }
    let(:logger) { double(:logger) }
    let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }

    describe '#create_route_service_instance_binding' do
      let(:route) { Route.make }
      let(:service_instance) { ManagedServiceInstance.make(space: route.space) }

      before do
        service_instance.service.requires = ['route_forwarding']
        service_instance.service.save
        allow(access_validator).to receive(:validate_access).and_return(true)
        stub_bind(service_instance)
      end

      it 'creates a binding' do
        expect(route.service_instance).to be_nil

        manager.create_route_service_instance_binding(route, service_instance)

        expect(route.reload.service_instance).to eq(service_instance)
      end

      it 'fails if the instance has another operation in progress' do
        service_instance.service_instance_operation = ServiceInstanceOperation.make state: 'in progress'
        expect {
          manager.create_route_service_instance_binding(route, service_instance)
        }.to raise_error do |e|
          expect(e).to be_a(Errors::ApiError)
          expect(e.message).to include('in progress')
        end
      end

      context 'when require route_forwarding is not set' do
        before do
          service_instance.service.requires = []
          service_instance.service.save
        end

        it 'raises Sequel::ValidationFailed' do
          expect {
            manager.create_route_service_instance_binding(route, service_instance)
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      context 'when the user does not have access' do
        before do
          allow(access_validator).to receive(:validate_access).and_raise('blah')
        end

        it 're-raises the error' do
          expect {
            manager.create_route_service_instance_binding(route, service_instance)
          }.to raise_error('blah')
        end
      end

      context 'when the route is invalid' do
        before do
          allow_any_instance_of(Route).to receive(:valid?).and_return(false)
        end

        it 'raises Sequel::ValidationFailed' do
          expect {
            manager.create_route_service_instance_binding(route, service_instance)
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      context 'and the bind request returns a syslog drain url' do
        before do
          stub_bind(service_instance, body: { syslog_drain_url: 'syslog.com/drain' }.to_json)
          stub_unbind_for_instance(service_instance)
        end

        it 'does not create a binding and raises an error for services that do not require syslog_drain' do
          expect {
            manager.create_route_service_instance_binding(route, service_instance)
          }.to raise_error do |e|
            expect(e).to be_a(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerInvalidSyslogDrainUrl)
            expect(e.message).to include('not registered as a logging service')
          end
          expect(route.reload.service_instance).to be_nil
        end

        it 'creates a binding for services that require syslog_drain' do
          service_instance.service.requires << 'syslog_drain'
          service_instance.service.save

          manager.create_route_service_instance_binding(route, service_instance)

          expect(route.reload.service_instance).to eq(service_instance)
        end
      end

      context 'when the service is not bindable' do
        before do
          service_instance.service.bindable = false
          service_instance.service.save
        end

        it 'raises ServiceInstanceNotBindable' do
          expect {
            manager.create_route_service_instance_binding(route, service_instance)
          }.to raise_error(ServiceInstanceBindingManager::ServiceInstanceNotBindable)
        end
      end

      describe 'orphan mitigation situations' do
        context 'when the broker returns an invalid syslog_drain_url' do
          before do
            stub_bind(service_instance, status: 201, body: { syslog_drain_url: 'syslog.com/drain' }.to_json)
          end

          it 'enqueues a DeleteOrphanedBinding job' do
            expect {
              manager.create_route_service_instance_binding(route, service_instance)
            }.to raise_error

            expect(Delayed::Job.count).to eq 1

            orphan_mitigating_job = Delayed::Job.first
            expect(orphan_mitigating_job).not_to be_nil
            expect(orphan_mitigating_job).to be_a_fully_wrapped_job_of Jobs::Services::DeleteOrphanedBinding

            expect(a_request(:delete, service_binding_url_pattern)).to_not have_been_made
          end
        end

        context 'when the broker returns an error on creation' do
          before do
            stub_bind(service_instance, status: 500)
          end

          it 'does not create a binding' do
            expect {
              manager.create_route_service_instance_binding(route, service_instance)
            }.to raise_error
            expect(route.reload.service_instance).to be_nil
          end

          it 'enqueues a DeleteOrphanedBinding job' do
            expect {
              manager.create_route_service_instance_binding(route, service_instance)
            }.to raise_error

            expect(Delayed::Job.count).to eq 1

            orphan_mitigating_job = Delayed::Job.first
            expect(orphan_mitigating_job).not_to be_nil
            expect(orphan_mitigating_job).to be_a_fully_wrapped_job_of Jobs::Services::DeleteOrphanedBinding

            expect(a_request(:delete, service_binding_url_pattern)).to_not have_been_made
          end
        end

        context 'when broker request is successful but the database fails to save the binding (Hail Mary)' do
          before do
            stub_bind(service_instance)
            stub_request(:delete, service_binding_url_pattern)

            allow_any_instance_of(Route).to receive(:save).and_raise('meow')
            allow(logger).to receive(:error)
            allow(logger).to receive(:info)

            expect {
              manager.create_route_service_instance_binding(route, service_instance)
            }.to raise_error('meow')
          end

          it 'immediately attempts to unbind the service instance' do
            expect(a_request(:put, service_binding_url_pattern)).to have_been_made.times(1)
            expect(a_request(:delete, service_binding_url_pattern)).to have_been_made.times(1)
          end

          it 'does not try to enqueue a delayed job for orphan mitigation' do
            orphan_mitigating_job = Delayed::Job.first
            expect(orphan_mitigating_job).to be_nil
          end

          context 'when the orphan mitigation unbind fails' do
            before do
              stub_request(:delete, service_binding_url_pattern).
                to_return(status: 500, body: {}.to_json)
            end

            it 'logs that the unbind failed' do
              expect(logger).to have_received(:error).with /Failed to save/
              expect(logger).to have_received(:error).with /Unable to delete orphaned service binding/
            end
          end
        end
      end
    end

    describe '#create_app_service_instance_binding' do
      let(:app) { AppFactory.make }
      let(:service_instance) { ManagedServiceInstance.make(space: app.space) }
      let(:binding_attrs) do
        {
          app_guid:              app.guid,
          service_instance_guid: service_instance.guid
        }
      end
      let(:arbitrary_parameters) { {} }

      before do
        allow(access_validator).to receive(:validate_access).and_return(true)
        credentials = { 'credentials' => '{}' }
        stub_bind(service_instance, body: credentials.to_json)
      end

      it 'creates a binding' do
        manager.create_app_service_instance_binding(service_instance.guid, app.guid, binding_attrs, arbitrary_parameters)

        expect(ServiceBinding.count).to eq(1)
      end

      it 'fails if the instance has another operation in progress' do
        service_instance.service_instance_operation = ServiceInstanceOperation.make state: 'in progress'
        expect {
          manager.create_app_service_instance_binding(service_instance.guid, app.guid, binding_attrs, arbitrary_parameters)
        }.to raise_error do |e|
          expect(e).to be_a(Errors::ApiError)
          expect(e.message).to include('in progress')
        end
      end

      context 'when the user does not have access' do
        before do
          allow(access_validator).to receive(:validate_access).and_raise('blah')
        end

        it 're-raises the error' do
          expect {
            manager.create_app_service_instance_binding(service_instance.guid, app.guid, binding_attrs, arbitrary_parameters)
          }.to raise_error('blah')
        end
      end

      context 'when the service binding is invalid' do
        before do
          allow_any_instance_of(ServiceBinding).to receive(:valid?).and_return(false)
        end

        it 'raises Sequel::ValidationFailed' do
          expect {
            manager.create_app_service_instance_binding(service_instance.guid, app.guid, binding_attrs, arbitrary_parameters)
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      context 'and the bind request returns a syslog drain url' do
        before do
          stub_bind(service_instance, body: { syslog_drain_url: 'syslog.com/drain' }.to_json)
          stub_unbind_for_instance(service_instance)
        end

        it 'does not create a binding and raises an error for services that do not require syslog_drain' do
          expect {
            manager.create_app_service_instance_binding(service_instance.guid, app.guid, binding_attrs, arbitrary_parameters)
          }.to raise_error do |e|
            expect(e).to be_a(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerInvalidSyslogDrainUrl)
            expect(e.message).to include('not registered as a logging service')
          end
          expect(ServiceBinding.count).to eq(0)
        end

        it 'creates a binding for services that require syslog_drain' do
          service_instance.service.requires = ['syslog_drain']
          service_instance.service.save

          manager.create_app_service_instance_binding(service_instance.guid, app.guid, binding_attrs, arbitrary_parameters)

          expect(ServiceBinding.count).to eq(1)
        end
      end

      context 'when the app does not exist' do
        it 'raises AppNotFound' do
          expect {
            manager.create_app_service_instance_binding(service_instance.guid, 'invalid', binding_attrs, arbitrary_parameters)
          }.to raise_error(ServiceInstanceBindingManager::AppNotFound)
        end
      end

      context 'when the service instance does not exist' do
        it 'raises ServiceInstanceNotFound' do
          expect {
            manager.create_app_service_instance_binding('invalid', app.guid, binding_attrs, arbitrary_parameters)
          }.to raise_error(ServiceInstanceBindingManager::ServiceInstanceNotFound)
        end
      end

      context 'when the service is not bindable' do
        before do
          service_instance.service.bindable = false
          service_instance.service.save
        end

        it 'raises ServiceInstanceNotBindable' do
          expect {
            manager.create_app_service_instance_binding(service_instance.guid, app.guid, binding_attrs, arbitrary_parameters)
          }.to raise_error(ServiceInstanceBindingManager::ServiceInstanceNotBindable)
        end
      end

      describe 'orphan mitigation situations' do
        context 'when the broker returns an invalid syslog_drain_url' do
          before do
            stub_bind(service_instance, status: 201, body: { syslog_drain_url: 'syslog.com/drain' }.to_json)
          end

          it 'enqueues a DeleteOrphanedBinding job' do
            expect {
              manager.create_app_service_instance_binding(service_instance.guid, app.guid, binding_attrs, arbitrary_parameters)
            }.to raise_error

            expect(Delayed::Job.count).to eq 1

            orphan_mitigating_job = Delayed::Job.first
            expect(orphan_mitigating_job).not_to be_nil
            expect(orphan_mitigating_job).to be_a_fully_wrapped_job_of Jobs::Services::DeleteOrphanedBinding

            expect(a_request(:delete, service_binding_url_pattern)).to_not have_been_made
          end
        end

        context 'when the broker returns an error on creation' do
          before do
            stub_bind(service_instance, status: 500)
          end

          it 'does not create a binding' do
            expect {
              manager.create_app_service_instance_binding(service_instance.guid, app.guid, binding_attrs, arbitrary_parameters)
            }.to raise_error
            expect(ServiceBinding.count).to eq 0
          end

          it 'enqueues a DeleteOrphanedBinding job' do
            expect {
              manager.create_app_service_instance_binding(service_instance.guid, app.guid, binding_attrs, arbitrary_parameters)
            }.to raise_error

            expect(Delayed::Job.count).to eq 1

            orphan_mitigating_job = Delayed::Job.first
            expect(orphan_mitigating_job).not_to be_nil
            expect(orphan_mitigating_job).to be_a_fully_wrapped_job_of Jobs::Services::DeleteOrphanedBinding

            expect(a_request(:delete, service_binding_url_pattern)).to_not have_been_made
          end
        end

        context 'when broker request is successful but the database fails to save the binding (Hail Mary)' do
          before do
            stub_bind(service_instance)
            stub_request(:delete, service_binding_url_pattern)

            allow_any_instance_of(ServiceBinding).to receive(:save).and_raise('meow')
            allow(logger).to receive(:error)
            allow(logger).to receive(:info)

            expect {
              manager.create_app_service_instance_binding(service_instance.guid, app.guid, binding_attrs, arbitrary_parameters)
            }.to raise_error('meow')
          end

          it 'immediately attempts to unbind the service instance' do
            expect(a_request(:put, service_binding_url_pattern)).to have_been_made.times(1)
            expect(a_request(:delete, service_binding_url_pattern)).to have_been_made.times(1)
          end

          it 'does not try to enqueue a delayed job for orphan mitigation' do
            orphan_mitigating_job = Delayed::Job.first
            expect(orphan_mitigating_job).to be_nil
          end

          context 'when the orphan mitigation unbind fails' do
            before do
              stub_request(:delete, service_binding_url_pattern).
                to_return(status: 500, body: {}.to_json)
            end

            it 'logs that the unbind failed' do
              expect(logger).to have_received(:error).with /Failed to save/
              expect(logger).to have_received(:error).with /Unable to delete orphaned service binding/
            end
          end
        end
      end
    end
  end
end
