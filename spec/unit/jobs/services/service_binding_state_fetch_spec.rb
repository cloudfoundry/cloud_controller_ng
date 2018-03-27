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
          let(:state) { 'in progress' }
          let(:description) { '10%' }
          let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }

          before do
            allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
          end

          context 'when the broker responds to last_operation' do
            before do
              allow(client).to receive(:fetch_service_binding_last_operation).and_return(last_operation: { state: state, description: description })

              # executes job and enqueues another job
              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceBindingStateFetch)
            end

            it 'updates the binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
              expect(service_binding.last_operation.description).to eq('10%')
            end

            context 'when the broker responds with failed last operation state' do
              let(:state) { 'failed' }
              let(:description) { 'something went wrong' }

              it 'updates the service binding last operation details' do
                service_binding.reload
                expect(service_binding.last_operation.state).to eq('failed')
                expect(service_binding.last_operation.description).to eq('something went wrong')
              end

              it 'should not enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 0
              end
            end

            context 'when enqueing the job reaches the max poll duration' do
              before do
                Timecop.travel(Time.now + max_duration.minutes + 1.minute) do
                  # executes job but does not enqueue another job
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end

              it 'should not enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 0
              end

              it 'should mark the service instance operation as failed' do
                service_binding.reload

                expect(service_binding.last_operation.state).to eq('failed')
                expect(service_binding.last_operation.description).to eq('Service Broker failed to bind within the required time.')
              end
            end
          end

          context 'when calling last operation responds with an error' do
            before do
              response = VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: 412, body: {})
              err = HttpResponseError.new('oops', 'uri', 'GET', response)
              allow(client).to receive(:fetch_service_binding_last_operation).and_raise(err)

              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
            end

            it 'maintains the service binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
            end

            context 'and the max poll duration has been reached' do
              before do
                Timecop.travel(Time.now + max_duration.minutes + 1.minute) do
                  # executes job but does not enqueue another job
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end

              it 'should not enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 0
              end
            end
          end

          context 'when calling last operation times out' do
            before do
              err = VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerApiTimeout.new('uri', 'GET', {})
              allow(client).to receive(:fetch_service_binding_last_operation).and_raise(err)
              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
            end

            it 'maintains the service binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
            end
          end

          context 'when a database operation fails' do
            before do
              allow(client).to receive(:fetch_service_binding_last_operation).and_return(last_operation: { state: state, description: description })
              allow(ServiceBinding).to receive(:first).and_raise(Sequel::Error)
              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
            end

            it 'maintains the service binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
            end
          end

          context 'when the service binding has been purged' do
            let(:job) { VCAP::CloudController::Jobs::Services::ServiceBindingStateFetch.new('bad-binding-guid') }

            it 'successfully exits the job' do
              # executes job and enqueues another job
              run_job(job)
            end

            it 'should not enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 0
            end
          end
        end
      end
    end
  end
end
