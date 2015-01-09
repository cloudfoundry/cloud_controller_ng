require 'spec_helper'

module VCAP::CloudController
  module Jobs::Services
    describe ServiceInstanceDeprovision do
      let(:client) { instance_double('VCAP::Services::ServiceBrokers::V2::Client') }

      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.new(service_plan: plan, space: space) }

      let(:name) { 'fake-name' }

      subject(:job) do
        VCAP::CloudController::Jobs::Services::ServiceInstanceDeprovision.new(name, {},
          service_instance.guid, service_instance.service_plan.guid)
      end

      describe '#perform' do
        before do
          allow(client).to receive(:deprovision)
          allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(client)
        end

        it 'deprovisions the service instance' do
          job.perform

          expect(client).to have_received(:deprovision) do |instance|
            expect(instance.guid).to eq service_instance.guid
            expect(instance.service_plan.guid).to eq service_instance.service_plan.guid
          end
        end
      end

      describe '#job_name_in_configuration' do
        it 'returns the name of the job' do
          expect(job.job_name_in_configuration).to eq(:service_instance_deprovision)
        end
      end

      describe '#max_attempts' do
        it 'returns 10' do
          expect(job.max_attempts).to eq 10
        end
      end

      describe '#reschedule_at' do
        it 'uses exponential backoff' do
          now = Time.now
          attempts = 5

          run_at = job.reschedule_at(now, attempts)
          expect(run_at).to eq(now + (2**attempts).minutes)
        end
      end
    end
  end
end
