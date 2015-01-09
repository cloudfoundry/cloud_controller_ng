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
        let(:mock_client) { double(:client, deprovision: nil) }

        before do
          allow(Delayed::Job).to receive(:enqueue)
          allow(VCAP::Request).to receive(:current_id).and_return('current_thread_id')
          allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(mock_client)
        end

        it 'enqueues a job with the correct queue and run_at time' do
          ServiceInstanceDeprovisioner.deprovision(client_attrs, service_instance)

          expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
            expect(opts[:queue]).to eq 'cc-generic'
            expect(opts[:run_at]).to be_within(0.01).of(Delayed::Job.db_time_now)
          end
        end

        it 'enqueues a job that deprovisions an instance' do
          mock_instance = double(:instance, guid: service_instance.guid)
          allow(VCAP::CloudController::ServiceInstance).to receive(:new).and_return(mock_instance)

          ServiceInstanceDeprovisioner.deprovision(client_attrs, service_instance)

          expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
            job.perform
          end
          expect(mock_client).to have_received(:deprovision).with(mock_instance)
        end

        it 'creates the job in the same context as the original request' do
          allow(VCAP::Request).to receive(:current_id=)

          ServiceInstanceDeprovisioner.deprovision(client_attrs, service_instance)

          expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
            job.perform
          end
          expect(VCAP::Request).to have_received(:current_id=).twice.with('current_thread_id')
        end

        it 'makes the job retryable' do
          ServiceInstanceDeprovisioner.deprovision(client_attrs, service_instance)

          expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
            expect(job).to be_a VCAP::CloudController::Jobs::RetryableJob
            expect(job.num_attempts).to eq 0
          end
        end
      end
    end
  end
end
