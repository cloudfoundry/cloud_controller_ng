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
        it 'enques a retryable ServiceInstanceUnbind job' do
          allow(Delayed::Job).to receive(:enqueue)

          Timecop.freeze do
            ServiceInstanceUnbinder.delayed_unbind(client_attrs, binding)

            expect(Delayed::Job).to have_received(:enqueue) do |job, opts|
              expect(opts[:queue]).to eq 'cc-generic'
              expect(opts[:run_at]).to be_within(0.01).of(Delayed::Job.db_time_now)

              expect(job).to be_a VCAP::CloudController::Jobs::RetryableJob
              expect(job.num_attempts).to eq 0

              inner_job = job.job
              expect(inner_job).to be_a VCAP::CloudController::Jobs::Services::ServiceInstanceUnbind
              expect(inner_job.name).to eq 'service-instance-unbind'
              expect(inner_job.client_attrs).to eq client_attrs
              expect(inner_job.binding_guid).to be(binding.guid)
              expect(inner_job.service_instance_guid).to be(binding.service_instance.guid)
              expect(inner_job.app_guid).to be(binding.app.guid)
            end
          end
        end
      end
    end
  end
end
