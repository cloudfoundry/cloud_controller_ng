require 'spec_helper'
require 'actions/service_binding_delete'

module VCAP::CloudController
  RSpec.describe ServiceBindingDelete do
    subject(:service_binding_delete) do
      described_class.new(UserAuditInfo.new(user_guid: user_guid, user_email: user_email))
    end
    let(:user_guid) { 'user-guid' }
    let(:user_email) { 'user@example.com' }

    describe '#single_delete_sync' do
      let(:service_binding) { ServiceBinding.make }
      let(:service_instance) { service_binding.service_instance }
      let(:client) { VCAP::Services::ServiceBrokers::V2::Client }
      let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }

      before do
        allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        allow(client).to receive(:unbind)
        stub_request(:delete, service_binding_url_pattern)
      end

      it 'deletes the service binding' do
        service_binding_delete.single_delete_sync(service_binding)
        expect(service_binding.exists?).to be_falsey
      end

      it 'creates an audit.service_binding.delete event' do
        service_binding_delete.single_delete_sync(service_binding)

        event = Event.last
        expect(event.type).to eq('audit.service_binding.delete')
        expect(event.actee).to eq(service_binding.guid)
        expect(event.actee_type).to eq('service_binding')
      end

      it 'asks the broker to unbind the instance' do
        expect(client).to receive(:unbind).with(service_binding)
        service_binding_delete.single_delete_sync(service_binding)
      end

      context 'when the service instance has another operation in progress' do
        before do
          service_binding.service_instance.service_instance_operation = ServiceInstanceOperation.make(state: 'in progress')
        end

        it 'raises an error' do
          expect {
            service_binding_delete.single_delete_sync(service_binding)
          }.to raise_error(CloudController::Errors::ApiError, /in progress/)
        end
      end

      context 'when the service broker client raises an error' do
        let(:error) { StandardError.new('kablooey') }

        before do
          allow(client).to receive(:unbind).and_raise(error)
        end

        it 're-raises the same error' do
          expect {
            service_binding_delete.single_delete_sync(service_binding)
          }.to raise_error(error)
        end
      end
    end

    describe '#single_delete_async' do
      let(:service_binding) { ServiceBinding.make }

      before do
        allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::Client).to receive(:unbind)
      end

      it 'returns a delete job for the service binding' do
        job = service_binding_delete.single_delete_async(service_binding)

        expect(job).to be_a_fully_wrapped_job_of(Jobs::DeleteActionJob)
        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        expect(service_binding.exists?).to be_falsey
      end
    end

    describe '#delete' do
      let(:service_binding1) { ServiceBinding.make }
      let(:service_binding2) { ServiceBinding.make }

      before do
        allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::Client).to receive(:unbind)
      end

      it 'deletes multiple bindings' do
        service_binding_delete.delete([service_binding1, service_binding2])
        expect(service_binding1).not_to exist
        expect(service_binding2).not_to exist
      end
    end
  end
end
