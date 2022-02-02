require 'spec_helper'
require 'jobs/v2/services/service_instance_state_fetch'
require_relative 'shared/when_broker_returns_retry_after_header'

module VCAP::CloudController
  module Jobs
    module Services
      RSpec.describe ServiceInstanceStateFetch, job_context: :worker do
        let(:proposed_service_plan) { ServicePlan.make }
        let(:proposed_maintenance_info) { { 'version' => '2.0' } }
        let(:maximum_polling_duration_for_plan) {}
        let(:service_plan) { ServicePlan.make(maximum_polling_duration: maximum_polling_duration_for_plan) }
        let(:service_instance) do
          operation = ServiceInstanceOperation.make(proposed_changes: {
            name: 'new-fake-name',
            service_plan_guid: proposed_service_plan.guid,
            maintenance_info: proposed_maintenance_info,
          })
          operation.save
          service_instance = ManagedServiceInstance.make(service_plan: service_plan)
          service_instance.save

          service_instance.service_instance_operation = operation
          service_instance
        end
        let(:broker) { service_instance.service_broker }
        let(:name) { 'fake-name' }

        let(:user) { User.make }
        let(:user_email) { 'fake@mail.foo' }

        let(:status) { 200 }
        let(:state) { 'succeeded' }
        let(:description) { 'description' }
        let(:response) do
          {
            type: 'should-not-change',
            state: state,
            description: description
          }
        end
        let(:max_duration) { 10080 }
        let(:request_attrs) do
          {
            dummy_data: 'dummy_data'
          }
        end

        subject(:job) do
          VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
            name,
            service_instance.guid,
            UserAuditInfo.new(user_guid: user.guid, user_email: user_email),
            request_attrs,
          )
        end

        def run_job(job)
          Jobs::Enqueuer.new(job, { queue: Jobs::Queues.generic, run_at: Delayed::Job.db_time_now }).enqueue
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end

        describe '#initialize' do
          let(:default_polling_interval) { 120 }
          let(:max_duration) { 10080 }

          before do
            config_override = {
              broker_client_default_async_poll_interval_seconds: default_polling_interval,
              broker_client_max_async_poll_duration_minutes: max_duration,
            }
            TestConfig.override(config_override)
          end

          context 'when the caller does not provide the maximum number of attempts' do
            it 'should the default configuration value' do
              Timecop.freeze(Time.now)
              expect(job.end_timestamp).to eq(Time.now + max_duration.minutes)
            end
          end

          context 'when the default poll interval is greater than the max value (24 hours)' do
            let(:default_polling_interval) { 24.hours + 1.minute }

            it 'enqueues the job using the maximum polling interval' do
              expect(job.poll_interval).to eq 24.hours
            end
          end

          context 'when the service plan has maximum_polling_duration' do
            let(:maximum_polling_duration_for_plan) { 36000000 } # in seconds

            context "when the config value is smaller than plan's maximum_polling_duration" do
              let(:max_duration) { 10 } # in minutes
              it 'should set end_timestamp to config value' do
                Timecop.freeze(Time.now)
                expect(job.end_timestamp).to eq(Time.now + max_duration.minutes)
              end
            end

            context "when the config value is greater than plan's maximum_polling_duration" do
              let(:max_duration) { 1068367346 } # in minutes
              it "should set end_timestamp to the plan's maximum_polling_duration value" do
                Timecop.freeze(Time.now)
                expect(job.end_timestamp).to eq(Time.now + maximum_polling_duration_for_plan.seconds)
              end
            end
          end

          context 'when there is a database error in fetching the plan' do
            it 'should set end_timestamp to config value' do
              allow(ManagedServiceInstance).to receive(:first) do |e|
                raise Sequel::Error.new(e)
              end
              Timecop.freeze(Time.now)
              expect(job.end_timestamp).to eq(Time.now + max_duration.minutes)
            end
          end
        end

        describe '#perform' do
          let(:last_operation_response) { { last_operation: { state: state, description: description }, response_code: 200 } }
          let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }

          before do
            allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
            allow(client).to receive(:fetch_service_instance_last_operation).and_return(last_operation_response)
          end

          describe 'updating the service instance description' do
            it 'saves the description provided by the broker' do
              expect { run_job(job) }.to change { service_instance.last_operation.reload.description }.
                from('description goes here').to('description')
            end

            context 'when the broker returns a long text description (mysql)' do
              let(:state) { 'in progress' }
              let(:description) { '123' * 512 }

              it 'saves the description in the database' do
                run_job(job)
                expect(service_instance.last_operation.reload.description).to eq description
              end
            end

            context 'when the broker does not return a description' do
              let(:last_operation_response) { { last_operation: { state: state } } }
              let(:response) do
                {
                  state: 'in progress'
                }
              end

              it 'does not update the field' do
                expect { run_job(job) }.not_to change { service_instance.last_operation.reload.description }.
                  from('description goes here')
              end
            end
          end

          context 'when all operations succeed and the state is `succeeded`' do
            let(:state) { 'succeeded' }

            context 'when the last operation type is `delete`' do
              before do
                service_instance.save_with_new_operation({}, { type: 'delete' })
              end

              it 'should delete the service instance' do
                run_job(job)

                expect(ManagedServiceInstance.first(guid: service_instance.guid)).to be_nil
              end

              it 'should create a delete event' do
                run_job(job)

                event = Event.find(type: 'audit.service_instance.delete')
                expect(event).to be
              end

              context 'when during client call the last operation was replaced' do
                before do
                  allow(client).to receive(:fetch_service_instance_last_operation) do
                    service_instance.save_with_new_operation(
                      {},
                      {
                        type: 'something else',
                        state: 'in progress'
                      }
                    )

                    last_operation_response
                  end
                end

                it 'did not do anything' do
                  run_job(job)

                  expect(ManagedServiceInstance.first(guid: service_instance.guid)).not_to be_nil
                  expect(Event.find(type: 'audit.service_instance.delete')).not_to be

                  db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
                  expect(db_service_instance.last_operation.state).not_to eq('succeeded')
                end
              end
            end

            context 'when the last operation type is `create`' do
              before do
                service_instance.save_with_new_operation({}, { type: 'create' })
              end

              context 'when during create, a delete operation was started' do
                before do
                  allow(client).to receive(:fetch_service_instance_last_operation) do
                    service_instance.save_with_new_operation(
                      {},
                      {
                        type: 'delete',
                        state: 'in progress'
                      }
                    )

                    last_operation_response
                  end

                  run_job(job)
                end

                let(:db_service_instance) { ManagedServiceInstance.first(guid: service_instance.guid) }

                it 'does not finish creating' do
                  expect(db_service_instance.last_operation.type).to eq('delete')
                  expect(db_service_instance.last_operation.state).to eq('in progress')
                  expect(Event.find(type: 'audit.service_instance.create')).not_to be
                end

                it 'does not delete' do
                  expect(db_service_instance).not_to be_nil
                  expect(Event.find(type: 'audit.service_instance.delete')).not_to be
                end
              end
            end

            context 'when the last operation type is `update`' do
              before do
                service_instance.last_operation.type = 'update'
                service_instance.last_operation.save
              end

              it 'should create an update event' do
                run_job(job)

                event = Event.find(type: 'audit.service_instance.update')
                expect(event).to be
              end
            end

            it 'fetches and updates the service instance state' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.last_operation.state).to eq('succeeded')
            end

            it 'applies the instance attributes that were proposed in the operation' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.maintenance_info).to eq(proposed_maintenance_info)
              expect(db_service_instance.service_plan).to eq(proposed_service_plan)
              expect(db_service_instance.name).to eq('new-fake-name')
            end

            it 'does not change the type field because of the broker' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.last_operation.type).to eq('create')
            end

            it 'should not enqueue another fetch job' do
              run_job(job)

              expect(Delayed::Job.count).to eq 0
            end

            context 'when user information is provided' do
              context 'and the last operation type is create' do
                it 'should create audit event' do
                  run_job(job)

                  event = Event.find(type: 'audit.service_instance.create')
                  expect(event).to be
                  expect(event.actee).to eq(service_instance.guid)
                  expect(event.metadata['request']).to have_key('dummy_data')
                end
              end
            end

            context 'when the user has gone away' do
              it 'should create an audit event' do
                user.destroy

                run_job(job)

                event = Event.find(type: 'audit.service_instance.create')
                expect(event).to be
                expect(event.actee).to eq(service_instance.guid)
                expect(event.metadata['request']).to have_key('dummy_data')
              end
            end
          end

          context 'when the state is `failed`' do
            let(:state) { 'failed' }

            it 'does not apply the instance attributes that were proposed in the operation' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.service_plan).to_not eq(proposed_service_plan)
              expect(db_service_instance.name).to eq(service_instance.name)
            end

            it 'fetches and updates the service instance state' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.last_operation.state).to eq('failed')
            end

            it 'should not enqueue another fetch job' do
              run_job(job)

              expect(Delayed::Job.count).to eq 0
            end

            it 'should not create an audit event' do
              run_job(job)

              expect(Event.find(type: 'audit.service_instance.create')).to be_nil
            end
          end

          context 'when all operations succeed, but the state is `in progress`' do
            let(:state) { 'in progress' }

            it 'fetches and updates the service instance state' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.last_operation.state).to eq('in progress')
            end

            it 'should enqueue another fetch job' do
              run_job(job)

              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)

              Timecop.freeze(Time.now + 1.hour) do
                Delayed::Job.last.invoke_job
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end

            it 'should not create an audit event' do
              run_job(job)

              expect(Event.find(type: 'audit.service_instance.create')).to be_nil
            end

            context 'when the last_operation is replaced with delete in progress' do
              let(:polling_interval) { 60 }

              before do
                TestConfig.config[:broker_client_default_async_poll_interval_seconds] = polling_interval
                run_job(job)
                service_instance.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
              end

              it 'is able to run the job again' do
                Timecop.travel(Time.now + polling_interval.seconds) do
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end
            end
          end

          context 'when saving to the database fails' do
            let(:state) { 'in progress' }
            before do
              allow(service_instance).to receive(:save) do |instance|
                raise Sequel::Error.new(instance)
              end
            end

            it 'should enqueue another fetch job' do
              run_job(job)

              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)
            end
          end

          context 'when fetching the service instance from the broker fails' do
            let(:state) { 'failed' }
            let(:description) { 'Something went wrong' }

            context 'due to an HttpRequestError' do
              before do
                err = HttpRequestError.new('oops', 'uri', 'GET', RuntimeError.new)
                allow(client).to receive(:fetch_service_instance_last_operation).and_raise(err)
              end

              it 'should enqueue another fetch job' do
                run_job(job)

                expect(Delayed::Job.count).to eq 1
                expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)
              end
            end

            context 'due to an HttpResponseError' do
              before do
                response = VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: 412, body: {})
                err = HttpResponseError.new('oops', 'GET', response)
                allow(client).to receive(:fetch_service_instance_last_operation).and_raise(err)
              end

              it 'should enqueue another fetch job' do
                run_job(job)

                expect(Delayed::Job.count).to eq 1
                expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)
              end
            end
          end

          context 'when the job has fetched for more than the max poll duration' do
            let(:state) { 'in progress' }

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
              service_instance.reload

              expect(service_instance.last_operation.state).to eq('failed')
              expect(service_instance.last_operation.description).to eq('Service Broker failed to provision within the required time.')
            end
          end

          context 'when enqueuing the job would exceed the max poll duration by the time it runs' do
            let(:state) { 'in progress' }

            it 'should not enqueue another fetch job' do
              Timecop.freeze(job.end_timestamp - (job.poll_interval * 0.5))
              run_job(job)

              Timecop.freeze(Time.now + job.poll_interval * 2)
              execute_all_jobs(expected_successes: 0, expected_failures: 0)
            end
          end

          context 'when the job was migrated before the addition of end_timestamp' do
            let(:state) { 'in progress' }

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
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)
            end
          end

          context 'when the poll_interval is changed after the job was created' do
            let(:default_polling_interval) { VCAP::CloudController::Config.config.get(:broker_client_default_async_poll_interval_seconds) }
            let(:new_polling_interval) { default_polling_interval * 2 }
            let(:state) { 'in progress' }

            before do
              expect(job.poll_interval).to eq(default_polling_interval)
              expect(default_polling_interval).not_to eq(new_polling_interval)
              TestConfig.override(broker_client_default_async_poll_interval_seconds: new_polling_interval)
            end

            it 'updates the poll interval after the next run' do
              Timecop.freeze(Time.now)
              first_run_time = Time.now

              Jobs::Enqueuer.new(job, { queue: Jobs::Queues.generic, run_at: first_run_time }).enqueue
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(Delayed::Job.count).to eq(1)

              old_next_run_time = first_run_time + default_polling_interval.seconds + 1.second
              Timecop.travel(old_next_run_time) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              new_next_run_time = first_run_time + new_polling_interval.seconds + 1.second
              Timecop.travel(new_next_run_time) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end
          end

          context 'when the service instance has been purged' do
            it 'exits without exploding' do
              service_instance.destroy

              expect {
                run_job(job)
              }.not_to raise_error
            end
          end

          context 'when the service broker credentials have changed since the job was enqueued' do
            let(:newClient) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }

            it 'uses the updated credentials' do
              updated_url      = 'http://new.url'
              updated_username = 'new-username'
              updated_password = 'new-password'

              Jobs::Enqueuer.new(job, { queue: Jobs::Queues.generic, run_at: Delayed::Job.db_time_now }).enqueue

              broker.update({
                broker_url:    updated_url,
                auth_username: updated_username,
                auth_password: updated_password
              })

              allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(newClient)
              allow(newClient).to receive(:fetch_service_instance_last_operation).and_return(last_operation_response)

              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(newClient).to have_received(:fetch_service_instance_last_operation)
            end
          end

          include_examples 'when brokers return Retry-After header', :fetch_service_instance_last_operation
        end

        describe '#job_name_in_configuration' do
          it 'returns the name of the job' do
            expect(job.job_name_in_configuration).to eq(:service_instance_state_fetch)
          end
        end

        describe '#end_timestamp' do
          let(:max_poll_duration) { VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes) }

          context 'when the job is new' do
            it 'adds the broker_client_max_async_poll_duration_minutes to the current time' do
              now = Time.now
              expected_end_timestamp = now + max_poll_duration.minutes
              Timecop.freeze now do
                expect(job.end_timestamp).to be_within(0.01).of(expected_end_timestamp)
              end
            end
          end

          context 'when the job is fetched from the database' do
            it 'returns the previously computed and persisted end_timestamp' do
              now = Time.now
              expected_end_timestamp = now + max_poll_duration.minutes

              job_id = nil
              Timecop.freeze now do
                enqueued_job = Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic, run_at: Time.now).enqueue
                job_id = enqueued_job.id
              end

              Timecop.freeze(now + 1.day) do
                rehydrated_job = Delayed::Job.first(id: job_id).payload_object.handler.handler
                expect(rehydrated_job.end_timestamp).to be_within(0.01).of(expected_end_timestamp)
              end
            end
          end
        end
      end
    end
  end
end
