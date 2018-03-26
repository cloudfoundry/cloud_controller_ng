require 'spec_helper'
require 'jobs/services/service_binding_state_fetch'

module VCAP::CloudController
  module Jobs
    module Services
      RSpec.describe ServiceBindingStateFetch, job_context: :worker do
        let(:service_binding_operation) { ServiceBindingOperation.make(state: 'in progress') }
        let(:service_binding) do
          service_binding = ServiceBinding.make
          service_binding.service_binding_operation = service_binding_operation
          service_binding
        end

        let(:max_duration) { 10080 }
        let(:default_polling_interval) { 60 }

        before do
          TestConfig.override({
            broker_client_default_async_poll_interval_seconds: default_polling_interval,
            broker_client_max_async_poll_duration_minutes: max_duration,
          })
        end

        def run_job(job)
          Jobs::Enqueuer.new(job, { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }).enqueue
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end

        describe '#perform' do
          let(:job) { VCAP::CloudController::Jobs::Services::ServiceBindingStateFetch.new(service_binding.guid) }

          context 'when the job has fetched for more than the max poll duration' do
            before do
              run_job(job)
              Timecop.travel(Time.now + max_duration.minutes + 1.minute) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end

            it 'should not enqueue another fetch job' do
              Timecop.freeze(Time.now + max_duration.minutes + 1.minute) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end
            end

            it 'should mark the service instance operation as failed' do
              service_binding.reload

              expect(service_binding.last_operation.state).to eq('failed')
              expect(service_binding.last_operation.description).to eq('Service Broker failed to bind within the required time.')
            end
          end

          context 'when enqueuing the job would exceed the max poll duration by the time it runs' do
            it 'should not enqueue another fetch job' do
              job = VCAP::CloudController::Jobs::Services::ServiceBindingStateFetch.new(service_binding.guid)
              job_timeout = Time.now + max_duration.minutes

              Timecop.freeze(job_timeout - 30.seconds)
              run_job(job)

              Timecop.freeze(job_timeout + 2.minutes)
              execute_all_jobs(expected_successes: 0, expected_failures: 0)
            end
          end

          context 'when the job was migrated before the addition of end_timestamp' do
            it 'should compute the end_timestamp based on the current time' do
              Timecop.freeze(Time.now)

              run_job(job)

              # should run enqueued job
              Timecop.travel(Time.now + max_duration.minutes - 1.minute) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end

              # should not run enqueued job
              Timecop.travel(Time.now + max_duration.minutes) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end
            end

            it 'should enqueue another fetch job' do
              run_job(job)

              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceBindingStateFetch)
            end
          end

        end
      end
    end
  end
end
