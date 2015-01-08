require 'spec_helper'

module VCAP::CloudController
  module ServiceBrokers::V2
    describe ServiceInstanceDeprovisioner do
      let(:client_attrs) { {} }

      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.new(service_plan: plan, space: space) }

      let(:name) { 'fake-name' }

      describe 'deprovision' do
        it 'enqueues a retryable ServiceInstanceDeprovision job' do
          allow(Delayed::Job).to receive(:enqueue)

          Timecop.freeze do
            ServiceInstanceDeprovisioner.deprovision(client_attrs, service_instance)

            expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
              expect(opts[:queue]).to eq 'cc-generic'
              expect(opts[:run_at]).to be_within(0.01).of(Delayed::Job.db_time_now)

              expect(job).to be_a VCAP::CloudController::Jobs::RetryableJob
              expect(job.num_attempts).to eq 0

              inner_job = job.job
              expect(inner_job).to be_instance_of(VCAP::CloudController::Jobs::Services::ServiceInstanceDeprovision)
              expect(inner_job.client_attrs).to be(client_attrs)
              expect(inner_job.service_instance_guid).to be(service_instance.guid)
              expect(inner_job.service_plan_guid).to be(service_instance.service_plan.guid)
            end
          end
        end
      end
    end
  end
end
