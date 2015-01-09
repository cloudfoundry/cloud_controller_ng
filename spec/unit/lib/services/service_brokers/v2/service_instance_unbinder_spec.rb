require 'spec_helper'

module VCAP::CloudController
  module ServiceBrokers::V2
    describe ServiceInstanceUnbinder do
      let(:client_attrs) { {} }
      let(:binding) do
        VCAP::CloudController::ServiceBinding.make(
          binding_options: { 'this' => 'that' }
        )
      end
      let(:name) { 'fake-name' }

      describe 'delayed_unbind' do
        let(:mock_client) { double(:client, unbind: nil) }

        before do
          allow(Delayed::Job).to receive(:enqueue)
          allow(VCAP::Request).to receive(:current_id).and_return('current_thread_id')
          allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(mock_client)
        end

        it 'enqueues a job with the correct queue and run_at time' do
          ServiceInstanceUnbinder.delayed_unbind(client_attrs, binding)

          expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
            expect(opts[:queue]).to eq 'cc-generic'
            expect(opts[:run_at]).to be_within(0.01).of(Delayed::Job.db_time_now)
          end
        end

        it 'enqueues a job that unbinds the instance' do
          mock_binding = double(:binding,
            guid: binding.guid,
            app_guid: binding.app_guid,
            service_instance_guid: binding.service_instance_guid)
          allow(VCAP::CloudController::ServiceBinding).to receive(:new).and_return(mock_binding)

          ServiceInstanceUnbinder.delayed_unbind(client_attrs, binding)

          expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
            job.perform
          end
          expect(mock_client).to have_received(:unbind).with(mock_binding)
        end

        it 'creates the job in the same context as the original request' do
          allow(VCAP::Request).to receive(:current_id=)

          ServiceInstanceUnbinder.delayed_unbind(client_attrs, binding)

          expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
            job.perform
          end
          expect(VCAP::Request).to have_received(:current_id=).twice.with('current_thread_id')
        end

        it 'makes the job retryable' do
          ServiceInstanceUnbinder.delayed_unbind(client_attrs, binding)

          expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
            expect(job).to be_a VCAP::CloudController::Jobs::RetryableJob
            expect(job.num_attempts).to eq 0
          end
        end
      end
    end
  end
end
