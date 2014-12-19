require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe ServiceInstanceUnbind do
      let(:client) { instance_double('VCAP::Services::ServiceBrokers::V2::Client') }
      let(:binding) do
        VCAP::CloudController::ServiceBinding.make(
          binding_options: { 'this' => 'that' }
        )
      end

      let(:name) { 'fake-name' }
      subject(:job) { VCAP::CloudController::Jobs::Runtime::ServiceInstanceUnbind.new(name, client, binding) }

      describe '#perform' do
        before do
          allow(client).to receive(:unbind).with(binding)
        end

        it 'unbinds the binding' do
          job.perform

          expect(client).to have_received(:unbind).with(binding)
        end
      end

      describe '#job_name_in_configuration' do
        it 'returns the name of the job' do
          expect(job.job_name_in_configuration).to eq(:service_instance_unbind)
        end
      end

      describe '#max_attempts' do
        it 'returns 3' do
          expect(job.max_attempts).to eq 3
        end
      end
    end
  end
end
