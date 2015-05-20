require 'spec_helper'
require 'actions/services/service_binding_create'

module VCAP::CloudController
  describe ServiceBindingCreate do
    let(:space) { Space.make }
    let(:service_instance) { ManagedServiceInstance.make(space: space) }
    let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }

    describe 'creating a service binding' do
      let(:logger) { double(Steno::Logger) }
      let(:binding_attrs) do
        {
          'service_instance_guid' => service_instance.guid,
          'app_guid' => App.make(space: space).guid,
        }
      end

      before do
        allow(logger).to receive :info
        allow(logger).to receive :error
      end

      context 'v2 service' do
        before do
          credentials = { 'credentials' => '{}' }
          stub_bind(service_instance, body: credentials.to_json)
        end

        it 'creates a binding' do
          ServiceBindingCreate.new(logger).bind(service_instance, binding_attrs, {})

          expect(ServiceBinding.count).to eq(1)
        end

        it 'fails if the instance has another operation in progress' do
          service_instance.service_instance_operation = ServiceInstanceOperation.make state: 'in progress'
          service_binding_create = ServiceBindingCreate.new(logger)
          _, errors = service_binding_create.bind(service_instance, binding_attrs, {})
          expect(errors.first).to be_instance_of Errors::ApiError
        end

        context 'and the bind request returns a syslog drain url' do
          let(:syslog_service_instance) { ManagedServiceInstance.make(space: space, service_plan: syslog_service_plan) }
          let(:syslog_service_plan) { ServicePlan.make(service: syslog_service) }
          let(:syslog_service) { Service.make(:v2, requires: ['syslog_drain']) }
          let(:syslog_binding_attrs) do
            {
              'service_instance_guid' => syslog_service_instance.guid,
              'app_guid' => App.make(space: space).guid,
            }
          end

          before do
            stub_bind(service_instance, body: { syslog_drain_url: 'syslog.com/drain' }.to_json)
            stub_bind(syslog_service_instance, body: { syslog_drain_url: 'syslog.com/drain' }.to_json)
            stub_unbind_for_instance(service_instance)
          end

          it 'does not create a binding and raises an error for services that do not require syslog_drain' do
            _, errors = ServiceBindingCreate.new(logger).bind(service_instance, binding_attrs, {})

            expect(errors.length).to eq 1
            expect(errors.first.message).to match /not registered as a logging service/
            expect(ServiceBinding.count).to eq(0)
          end

          it 'creates a binding for services that require syslog_drain' do
            binding, errors = ServiceBindingCreate.new(logger).bind(syslog_service_instance, syslog_binding_attrs, {})

            expect(errors).to be_empty
            expect(binding).not_to be_nil
            expect(ServiceBinding.count).to eq(1)
          end
        end
      end

      context 'v1 service' do
        let(:service_instance) { ManagedServiceInstance.make(:v1, space: space) }

        before do
          stub_v1_broker
        end

        it 'creates a binding' do
          binding, errors = ServiceBindingCreate.new(logger).bind(service_instance, binding_attrs, {})

          expect(errors).to be_empty
          expect(binding).not_to be_nil
          expect(ServiceBinding.count).to eq(1)
        end
      end

      describe 'orphan mitigation situations' do
        context 'when the broker returns an invalid syslog_drain_url' do
          before do
            stub_bind(service_instance, status: 201, body: { syslog_drain_url: 'syslog.com/drain' }.to_json)
          end

          it 'enqueues a DeleteOrphanedBinding job' do
            _, errors = ServiceBindingCreate.new(logger).bind(service_instance, binding_attrs, {})

            expect(errors.length).to eq 1

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
            ServiceBindingCreate.new(logger).bind(service_instance, binding_attrs, {})

            expect(ServiceBinding.count).to eq 0
          end

          it 'enqueues a DeleteOrphanedBinding job' do
            _, errors = ServiceBindingCreate.new(logger).bind(service_instance, binding_attrs, {})

            expect(errors.length).to eq 1

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

            ServiceBindingCreate.new(logger).bind(service_instance, binding_attrs, {})
          end

          it 'immediately attempts to unbind the service instance' do
            expect(a_request(:put, service_binding_url_pattern)).to have_been_made.times(1)
            expect(a_request(:delete, service_binding_url_pattern)).to have_been_made.times(1)
          end

          it 'does not try to enqueue a delayed job for orphan mitigation' do
            orphan_mitigating_job = Delayed::Job.first
            expect(orphan_mitigating_job).to be_nil
          end

          it 'returns the appropriate error' do
            _, errors = ServiceBindingCreate.new(logger).bind(service_instance, binding_attrs, {})
            expect(errors.length).to eq(1)
            expect(errors.first.message).to match('meow')
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
