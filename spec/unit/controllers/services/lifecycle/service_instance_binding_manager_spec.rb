require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceInstanceBindingManager do
    let(:manager) { ServiceInstanceBindingManager.new(access_validator, logger) }
    let(:event_repository) { double(:event_repository, record_service_binding_event: true, record_service_instance_event: true) }
    let(:access_validator) { double(:access_validator) }
    let(:logger) { double(:logger) }
    let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }

    before do
      allow(::CloudController::DependencyLocator.instance).to receive(:services_event_repository) { event_repository }
    end

    describe '#create_route_service_instance_binding' do
      let(:route) { Route.make }
      let(:route_service_url) { 'https://some-rs-url' }
      let(:route_services_enabled) { true }

      context 'user provided service instance' do
        let(:service_instance) do
          UserProvidedServiceInstance.make(
            space: route.space,
            route_service_url: route_service_url,
          )
        end

        before do
          allow(access_validator).to receive(:validate_access).with(:update, anything).and_return(true)
        end

        it 'creates a binding and sets the route_service_url' do
          route_binding = manager.create_route_service_instance_binding(route.guid, service_instance.guid, {}, route_services_enabled)

          expect(route_binding.service_instance).to eq service_instance
          expect(route_binding.route).to eq route
          expect(route_binding.route_service_url).to eq service_instance.route_service_url
        end

        context 'when route services are disabled' do
          let(:route_services_enabled) { false }

          it 'raises a RouteServiceDisabled error' do
            expect {
              manager.create_route_service_instance_binding(route.guid, service_instance.guid, {}, route_services_enabled)
            }.to raise_error ServiceInstanceBindingManager::RouteServiceDisabled
          end
        end
      end

      context 'managed service instance' do
        let(:service_instance) { ManagedServiceInstance.make(:routing, space: route.space) }
        let(:arbitrary_parameters) { { 'arbitrary' => 'parameters' } }

        before do
          allow(access_validator).to receive(:validate_access).with(:update, anything).and_return(true)
          stub_bind(service_instance, { body: { route_service_url: route_service_url }.to_json })
        end

        it 'creates a binding' do
          expect(route.service_instance).to be_nil
          expect(service_instance.routes).to be_empty

          route_binding = manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)

          expect(route_binding.service_instance).to eq service_instance
          expect(route_binding.route).to eq route
          expect(route_binding.route_service_url).to eq route_service_url
          expect(route.reload.service_instance).to eq service_instance
          expect(service_instance.reload.routes).to include route
        end

        it 'tells the broker client to bind the route and the service instance' do
          expect_any_instance_of(VCAP::Services::ServiceBrokers::V2::Client).
            to receive(:bind).with(anything, arbitrary_parameters).
            and_return({})

          manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
        end

        it 'fails if the instance has another operation in progress' do
          service_instance.service_instance_operation = ServiceInstanceOperation.make state: 'in progress'
          expect {
            manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
          }.to raise_error do |e|
            expect(e).to be_a(CloudController::Errors::ApiError)
            expect(e.message).to include('in progress')
          end
        end

        context 'when route services are disabled' do
          let(:route_services_enabled) { false }

          it 'raises a RouteServiceDisabled error' do
            expect {
              manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
            }.to raise_error ServiceInstanceBindingManager::RouteServiceDisabled
          end
        end

        context 'when the route does not exist' do
          it 'raises a RouteNotFound error and does not call the broker' do
            expect {
              manager.create_route_service_instance_binding('not-a-guid', service_instance.guid, arbitrary_parameters, route_services_enabled)
            }.to raise_error ServiceInstanceBindingManager::RouteNotFound

            expect(a_request(:put, service_binding_url_pattern)).not_to have_been_made
          end
        end

        context 'when the service instance does not exist' do
          it 'raises a ServiceInstanceNotFound error' do
            expect {
              manager.create_route_service_instance_binding(route.guid, 'not-a-guid', arbitrary_parameters, route_services_enabled)
            }.to raise_error ServiceInstanceBindingManager::ServiceInstanceNotFound

            expect(a_request(:put, service_binding_url_pattern)).to_not have_been_made
          end
        end

        context 'when the route is already bound to a service_instance' do
          before do
            RouteBinding.make(route: route, service_instance: ManagedServiceInstance.make(:routing, space: route.space))
          end

          it 'raises a already bound to service instance error' do
            expect {
              manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
            }.to raise_error ServiceInstanceBindingManager::RouteAlreadyBoundToServiceInstance

            expect(a_request(:put, service_binding_url_pattern)).to_not have_been_made
          end
        end

        context 'when the route is already bound to the same service_instance' do
          before do
            RouteBinding.make(route: route, service_instance: service_instance)
          end

          it 'raises a service already bound to same route error' do
            expect {
              manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
            }.to raise_error ServiceInstanceBindingManager::ServiceInstanceAlreadyBoundToSameRoute

            expect(a_request(:put, service_binding_url_pattern)).to_not have_been_made
          end
        end

        context 'binding a service instance to a route' do
          context 'when the route has no apps' do
            it 'does not send request to diego' do
              expect_any_instance_of(Diego::NsyncClient).not_to receive(:desire_app)

              manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
            end
          end

          context 'when the route has an app', isolation: :truncation do
            before do
              app = AppFactory.make(diego: true, space: route.space, state: 'STARTED')
              RouteMappingModel.make(app: app.app, route: route, process_type: app.type)
            end

            it 'sends a message on to diego' do
              expect_any_instance_of(Diego::NsyncClient).to receive(:desire_app) do |*args|
                message = args.last
                expect(message).to match(/route_service_url/)
              end
              manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
            end

            context 'when the app does not use diego' do
              before do
                non_diego_app = AppFactory.make(diego: false, space: route.space, state: 'STARTED')
                RouteMappingModel.make(app: non_diego_app.app, route: route, process_type: non_diego_app.type)
              end

              it 'raises an error' do
                expect {
                  manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
                }.to raise_error(ServiceInstanceBindingManager::RouteServiceRequiresDiego)
              end
            end
          end
        end

        context 'when require route_forwarding is not set' do
          before do
            service_instance.service.requires = []
            service_instance.service.save
          end

          it 'raises Sequel::ValidationFailed' do
            expect {
              manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
            }.to raise_error(Sequel::ValidationFailed)
          end
        end

        context 'when the user does not have access' do
          before do
            allow(access_validator).to receive(:validate_access).with(:update, anything).and_raise('blah')
          end

          it 're-raises the error' do
            expect {
              manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
            }.to raise_error('blah')
          end
        end

        context 'when the route_binding is invalid' do
          before do
            allow_any_instance_of(RouteBinding).to receive(:valid?).and_return(false)
          end

          it 'raises Sequel::ValidationFailed' do
            expect {
              manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
            }.to raise_error(Sequel::ValidationFailed)
          end
        end

        context 'and the bind request does not return a route_service_url' do
          before do
            stub_bind(service_instance, body: { credentials: 'credentials' }.to_json)
            stub_unbind_for_instance(service_instance)
          end

          it 'creates the binding but does not notify diego' do
            expect(route.service_instance).to be_nil
            expect(service_instance.routes).to be_empty

            route_binding = manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)

            expect(route_binding.service_instance).to eq service_instance
            expect(route_binding.route).to eq route
            expect(route_binding.route_service_url).to be_nil
            expect(route.reload.service_instance).to eq service_instance
            expect(service_instance.reload.routes).to include route
          end
        end

        context 'when the service is not bindable' do
          before do
            service_instance.service.bindable = false
            service_instance.service.save
          end

          it 'raises ServiceInstanceNotBindable' do
            expect {
              manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
            }.to raise_error(ServiceInstanceBindingManager::ServiceInstanceNotBindable)

            expect(a_request(:put, service_binding_url_pattern)).to_not have_been_made
          end
        end

        describe 'orphan mitigation situations' do
          context 'when the broker returns an invalid syslog_drain_url' do
            before do
              stub_bind(service_instance, status: 201, body: { syslog_drain_url: 'syslog.com/drain' }.to_json)
            end

            it 'enqueues a DeleteOrphanedBinding job' do
              expect {
                manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
              }.to raise_error(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerInvalidSyslogDrainUrl)

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
                manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
              }.to raise_error(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)
              expect(service_instance.reload.routes).to be_empty
              expect(route.reload.service_instance).to be_nil
            end

            it 'enqueues a DeleteOrphanedBinding job' do
              expect {
                manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
              }.to raise_error(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)

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

              allow_any_instance_of(RouteBinding).to receive(:save).and_raise('meow')
              allow(logger).to receive(:error)
              allow(logger).to receive(:info)

              expect {
                manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
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

          context 'when diego does not return a success', isolation: :truncation do
            before do
              allow(logger).to receive(:info)
              allow(logger).to receive(:error)

              app = AppFactory.make(diego: true, space: route.space, state: 'STARTED')
              RouteMappingModel.make(app: app.app, route: route, process_type: app.type)

              process_guid = Diego::ProcessGuid.from_process(app)
              stub_request(:delete, service_binding_url_pattern).to_return(status: 200, body: {}.to_json)

              expect {
                stub_request(:put, "#{TestConfig.config[:diego][:nsync_url]}/v1/apps/#{process_guid}").to_return(status: 500)
                manager.create_route_service_instance_binding(route.guid, service_instance.guid, arbitrary_parameters, route_services_enabled)
              }.to raise_error(CloudController::Errors::ApiError, /desire app failed: 500/i)
            end

            it 'orphans the route binding and mitigates it' do
              expect(a_request(:delete, service_binding_url_pattern)).to have_been_made.times(1)
              expect(RouteBinding.find(service_instance_id: service_instance.id, route_id: route.id)).to be_nil
            end

            it 'logs that nsync failed to update' do
              expect(logger).to have_received(:error).with /Failed to update/
            end
          end
        end
      end
    end

    describe '#delete_route_service_binding' do
      context 'user provided service instance' do
        let(:route) { Route.make }
        let(:route_service_url) { 'https://my-rs.example.com' }
        let(:route_binding) do
          RouteBinding.make(service_instance: service_instance,
                            route: route,
                            route_service_url: route_service_url)
        end
        let(:service_instance) do
          UserProvidedServiceInstance.make(:routing,
                                           space: route.space,
                                           route_service_url: route_service_url)
        end

        before do
          allow(access_validator).to receive(:validate_access).with(:update, anything).and_return(true)

          app = AppFactory.make(diego: true, space: route.space, state: 'STARTED')
          RouteMappingModel.make(app: app.app, route: route, process_type: app.type)

          process_guid = Diego::ProcessGuid.from_process(app)
          stub_request(:put, "#{TestConfig.config[:diego][:nsync_url]}/v1/apps/#{process_guid}").to_return(status: 202)
        end

        it 'unbinds the route and service instance', isolation: :truncation do
          expect(route_binding.service_instance).to eq service_instance
          expect(route_binding.route).to eq route
          expect(route_binding.route_service_url).to eq service_instance.route_service_url

          expect_any_instance_of(Diego::NsyncClient).to receive(:desire_app) do |*args|
            message = args.last
            expect(message).not_to match(/route_service_url/)
          end

          expect {
            manager.delete_route_service_instance_binding(route.guid, service_instance.guid)
          }.to change { RouteBinding.count }.by(-1)

          expect {
            route_binding.reload
          }.to raise_error 'Record not found'
        end
      end

      context 'managed service instances' do
        let(:route_binding) { RouteBinding.make }
        let(:service_instance) { route_binding.service_instance }
        let(:route) { route_binding.route }
        before do
          stub_unbind(route_binding)
          allow(access_validator).to receive(:validate_access).with(:update, anything).and_return(true)
        end

        it 'sends an unbind request to the service broker' do
          manager.delete_route_service_instance_binding(route.guid, service_instance.guid)

          route_binding_url_pattern = /#{service_binding_url_pattern}#{route_binding.guid}/
          expect(a_request(:delete, route_binding_url_pattern)).to have_been_made
        end

        context 'when the route does not exist' do
          it 'raises a RouteNotFound error and does not call the broker' do
            expect {
              manager.delete_route_service_instance_binding('not-a-guid', service_instance.guid)
            }.to raise_error ServiceInstanceBindingManager::RouteNotFound

            expect(a_request(:delete, service_binding_url_pattern)).not_to have_been_made
          end
        end

        context 'when the service instance does not exist' do
          it 'raises a ServiceInstanceNotFound error' do
            expect {
              manager.delete_route_service_instance_binding(route.guid, 'not-a-guid')
            }.to raise_error ServiceInstanceBindingManager::ServiceInstanceNotFound

            expect(a_request(:delete, service_binding_url_pattern)).to_not have_been_made
          end
        end

        context 'when the route and service instance are not bound' do
          it 'raises a RouteBindingNotFound error' do
            expect {
              manager.delete_route_service_instance_binding(Route.make.guid, service_instance.guid)
            }.to raise_error ServiceInstanceBindingManager::RouteBindingNotFound

            expect(a_request(:delete, service_binding_url_pattern)).to_not have_been_made
          end
        end

        it 'deletes the binding and removes associations from routes and service_instances' do
          expect(route.service_instance).to eq service_instance
          expect(service_instance.routes).to include route

          manager.delete_route_service_instance_binding(route.guid, service_instance.guid)

          expect(route_binding.exists?).to be_falsey
          expect(route.reload.service_instance).to be_nil
          expect(service_instance.reload.routes).to be_empty
        end

        context 'when the user does not have authority to delete a binding' do
          before do
            allow(access_validator).to receive(:validate_access).with(:update, anything).and_raise('blah')
          end

          it 'raises an error' do
            expect {
              manager.delete_route_service_instance_binding(route.guid, service_instance.guid)
            }.to raise_error('blah')
          end
        end

        it 'fails if the instance has another operation in progress' do
          allow(logger).to receive(:error)

          service_instance.service_instance_operation = ServiceInstanceOperation.make state: 'in progress'
          expect {
            manager.delete_route_service_instance_binding(route.guid, service_instance.guid)
          }.to raise_error do |e|
            expect(e).to be_a(CloudController::Errors::ApiError)
            expect(e.message).to include('in progress')
          end

          expect(logger).to have_received(:error).with /in progress/
        end

        context 'when service broker returns a 500 on unbind' do
          before do
            stub_unbind(route_binding, status: 500)
            allow(logger).to receive(:error)
          end

          it 'does not delete the binding' do
            expect {
              manager.delete_route_service_instance_binding(route.guid, service_instance.guid)
            }.to raise_error VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse

            expect(route_binding.exists?).to be_truthy
            expect(logger).to have_received(:error).with /Failed to delete/
          end
        end
      end
    end
  end
end
