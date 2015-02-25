require 'spec_helper'

module VCAP::Services
  module ServiceBrokers::V2
    describe ServiceInstanceStatePoller do
      let(:client_attrs) { { uri: 'broker.com' } }

      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.new(service_plan: plan, space: space) }
      let(:polling_interval) { 120 }

      before do
        allow(VCAP::CloudController::Config).to receive(:config).and_return({ broker_client_default_async_poll_interval_seconds: polling_interval })
      end

      describe 'poll_service_instance_state' do
        it 'enqueues a ServiceInstanceStateFetch job' do
          mock_enqueuer = double(:enqueuer, enqueue: nil)
          allow(VCAP::CloudController::Jobs::Enqueuer).to receive(:new).and_return(mock_enqueuer)

          VCAP::Services::ServiceBrokers::V2::ServiceInstanceStatePoller.new.poll_service_instance_state(client_attrs, service_instance)

          expect(VCAP::CloudController::Jobs::Enqueuer).to have_received(:new) do |job, opts|
            expect(opts[:queue]).to eq 'cc-generic'
            expect(opts[:run_at]).to be_within(1.0).of(Delayed::Job.db_time_now + polling_interval.seconds)

            expect(job).to be_a VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch
            expect(job.name).to eq 'service-instance-state-fetch'
            expect(job.client_attrs).to eq client_attrs
            expect(job.service_instance_guid).to eq service_instance.guid
          end

          expect(mock_enqueuer).to have_received(:enqueue)
        end
      end
    end
  end
end
