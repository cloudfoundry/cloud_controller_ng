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
        before do
          allow(Delayed::Job).to receive(:enqueue)
          allow(VCAP::Request).to receive(:current_id).and_return('current_thread_id')
        end

        it 'enqueues a job that unbinds the instance' do
          ServiceInstanceUnbinder.delayed_unbind(client_attrs, binding)

          expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
            unbind_job = job.job.job
            expect(unbind_job).to be_a VCAP::CloudController::Jobs::Services::ServiceInstanceUnbind
            expect(unbind_job.name).to eq 'service-instance-unbind'
            expect(unbind_job.client_attrs).to eq client_attrs
            expect(unbind_job.binding_guid).to be(binding.guid)
            expect(unbind_job.service_instance_guid).to be(binding.service_instance.guid)
            expect(unbind_job.app_guid).to be(binding.app.guid)
          end
        end

        it 'creates the job in the same context as the original request' do
          ServiceInstanceUnbinder.delayed_unbind(client_attrs, binding)

          expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
            request_job = job.job
            expect(request_job).to be_a VCAP::CloudController::Jobs::RequestJob
            expect(request_job.request_id).to eq 'current_thread_id'
          end
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
