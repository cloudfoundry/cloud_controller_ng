require 'spec_helper'

module VCAP::Services
  module ServiceBrokers::V2
    describe ServiceInstanceStatePoller do
      let(:client_attrs) { { uri: 'broker.com' } }

      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.new(service_plan: plan, space: space) }

      describe 'poll_service_instance_state' do
        it 'enqueues a ServiceInstanceStateFetch job' do
          mock_enqueuer = double(:enqueuer, enqueue: nil)
          allow(VCAP::CloudController::Jobs::Enqueuer).to receive(:new).and_return(mock_enqueuer)

          ServiceInstanceStatePoller.new.poll_service_instance_state(client_attrs, service_instance)

          expect(VCAP::CloudController::Jobs::Enqueuer).to have_received(:new) do |job, opts|
            expect(opts[:queue]).to eq 'cc-generic'
            expect(opts[:run_at]).to be_within(0.01).of(Delayed::Job.db_time_now)

            expect(job).to be_a VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch
            expect(job.name).to eq 'service-instance-state-fetch'
            expect(job.client_attrs).to eq client_attrs
            expect(job.service_instance_guid).to eq service_instance.guid
            expect(job.service_plan_guid).to eq service_instance.service_plan.guid
          end

          expect(mock_enqueuer).to have_received(:enqueue)
        end
      end
    end
  end
end
