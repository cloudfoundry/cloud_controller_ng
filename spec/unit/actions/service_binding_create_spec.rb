require 'spec_helper'
require 'actions/service_binding_create'

module VCAP::CloudController
  describe ServiceBindingCreate do
    let(:service_instance) { ManagedServiceInstance.make }
    let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }

    describe 'creating a service binding' do
      let(:logger) { double(Steno::Logger) }
      let(:binding_attrs) do
        {
          'service_instance_guid' => service_instance.guid,
          'app_guid' => App.make.guid,
        }
      end

      describe 'orphan mitigation situations' do
        context 'when the broker returns an error on creation' do
          before do
            stub_bind(service_instance, status: 500)
          end

          it 'does not create a binding' do
            ServiceBindingCreate.new(logger).bind(service_instance, binding_attrs, {})

            expect(ServiceBinding.count).to eq 0
          end

          it 'enqueues a ServiceInstanceUnbind job' do
            _, errors = ServiceBindingCreate.new(logger).bind(service_instance, binding_attrs, {})

            expect(errors.length).to eq 1

            expect(Delayed::Job.count).to eq 1

            orphan_mitigating_job = Delayed::Job.first
            expect(orphan_mitigating_job).not_to be_nil
            expect(orphan_mitigating_job).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceUnbind

            expect(a_request(:delete, service_binding_url_pattern)).to_not have_been_made
          end
        end

        context 'when broker request is successful but the database fails to save the binding (Hail Mary)' do
          before do
            stub_bind(service_instance)
            stub_request(:delete, service_binding_url_pattern)

            allow_any_instance_of(ServiceBinding).to receive(:save).and_raise

            allow(logger).to receive :error

            ServiceBindingCreate.new(logger).bind(service_instance, binding_attrs, {})
          end

          it 'immediately attempts to unbind the service instance' do
            expect(a_request(:put, service_binding_url_pattern)).to have_been_made.times(1)
            expect(a_request(:delete, service_binding_url_pattern)).to have_been_made.times(1)
          end

          it 'does not try to enqueue an orphan mitigation job' do
            orphan_mitigating_job = Delayed::Job.first
            expect(orphan_mitigating_job).to be_nil
          end

          context 'when the orphan mitigation unbind fails' do
            before do
              stub_request(:delete, service_binding_url_pattern).
                  to_return(status: 500, body: {}.to_json)
            end

            it 'logs that the unbind failed' do
              expect(logger).to have_received(:error).with /Unable to unbind/
            end
          end
        end
      end
    end
  end
end
