require 'spec_helper'
require 'actions/services/service_key_create'

module VCAP::CloudController
  RSpec.describe ServiceKeyCreate do
    let(:service_instance) { ManagedServiceInstance.make }
    let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }

    describe 'creating a service key' do
      let(:logger) { double(Steno::Logger) }
      let(:key_attrs) do
        {
            'service_instance_guid' => service_instance.guid,
        }
      end

      before do
        allow(logger).to receive :error
        allow(logger).to receive :info
      end

      it 'fails if the instance has another operation in progress' do
        service_instance.service_instance_operation = ServiceInstanceOperation.make state: 'in progress'
        service_key_create = ServiceKeyCreate.new(logger)
        _, errors = service_key_create.create(service_instance, key_attrs, {})
        expect(errors.first).to be_instance_of CloudController::Errors::ApiError
      end

      describe 'orphan mitigation situations' do
        context 'when the broker returns an error on creation' do
          before do
            stub_bind(service_instance, status: 500)
          end

          it 'does not create a key' do
            ServiceKeyCreate.new(logger).create(service_instance, key_attrs, {})

            expect(ServiceKey.count).to eq 0
          end
        end

        context 'when broker request is successful but the database fails to save the key (Hail Mary)' do
          before do
            stub_bind(service_instance)
            stub_request(:delete, service_binding_url_pattern)

            allow_any_instance_of(ServiceKey).to receive(:save).and_raise

            ServiceKeyCreate.new(logger).create(service_instance, key_attrs, {})
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
              expect(logger).to have_received(:error).with /Failed to save/
              expect(logger).to have_received(:error).with /Unable to delete orphaned service key/
            end
          end
        end
      end
    end
  end
end
