require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe ServiceInstanceDeprovision do
      let(:client) { instance_double('VCAP::Services::ServiceBrokers::V2::Client') }

      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.new(service_plan: plan, space: space) }

      let(:name) { 'fake-name' }
      subject(:job) { VCAP::CloudController::Jobs::Runtime::ServiceInstanceDeprovision.new(name, client, service_instance) }

      describe '#perform' do
        before do
          allow(client).to receive(:deprovision).with(service_instance)
        end

        it 'deprovisions the service instance' do
          job.perform

          expect(client).to have_received(:deprovision).with(service_instance)
        end
      end

      describe '#job_name_in_configuration' do
        it 'returns the name of the job' do
          expect(job.job_name_in_configuration).to eq(:service_instance_deprovision)
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
