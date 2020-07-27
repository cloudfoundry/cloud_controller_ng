require 'spec_helper'
require 'jobs/v3/create_service_instance_job'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    class FakeAsyncOperation < ServiceInstanceAsyncJob
      attr_accessor :request_attr

      def operation_type
        'fake-operation'
      end

      def operation
        :fakeoperation
      end

      def operation_succeeded; end

      def send_broker_request(_) end
    end

    RSpec.describe ServiceInstanceAsyncJob do
      let(:logger) { instance_double(Steno::Logger, error: nil, info: nil, warn: nil) }
      let(:service_offering) { Service.make }
      let(:maximum_polling_duration) { nil }
      let(:service_plan) { ServicePlan.make(service: service_offering, maximum_polling_duration: maximum_polling_duration) }
      let(:service_instance) {
        si = ManagedServiceInstance.make(service_plan: service_plan)
        si.save_with_new_operation({}, { type: operation, state: 'in progress' })
        si.reload
      }
      let(:audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'foo@example.com') }
      let(:guid) { service_instance.guid }
      let(:job) do
        FakeAsyncOperation.new(guid, audit_info).tap do |j|
          j.request_attr = { some_data: 'some_data' }
        end
      end
      let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }
      let(:operation) { 'fake-operation' }

      before do
        allow(Steno).to receive(:logger).and_return(logger)
        allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        allow(client).to receive(:fetch_service_instance_last_operation)
      end

      it_behaves_like 'delayed job', described_class

      it { expect(described_class).to be < VCAP::CloudController::Jobs::ReoccurringJob }

      describe '#perform' do
        let(:operation_response) { {} }
        before do
          allow_any_instance_of(FakeAsyncOperation).to receive(:send_broker_request).and_return(operation_response)
          allow_any_instance_of(FakeAsyncOperation).to receive(:operation_succeeded)
        end

        it 'raises by default if the service instance does not exist' do
          service_instance.destroy

          expect { job.perform }.to raise_error(
            CloudController::Errors::ApiError,
            /The service instance could not be found/
          )
        end

        it 'returns if gone! is defined' do
          service_instance.destroy
          allow(job).to receive(:gone!).and_return(true)

          expect { job.perform }.not_to raise_error
          expect(job).to have_received(:gone!)
        end

        context 'when there is another operation in progress' do
          before do
            service_instance.save_with_new_operation({}, { type: 'some-other-operation', state: 'in progress', description: 'barz' })
          end

          it 'raises an error' do
            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              /could not be completed: some-other-operation in progress/
            )
          end

          it 'does not update the last operation' do
            expect(service_instance.last_operation.type).to eq('some-other-operation')
            expect(service_instance.last_operation.state).to eq('in progress')
            expect(service_instance.last_operation.description).to eq('barz')
          end
        end

        context 'when executed for the first time' do
          context 'computes the maximum duration' do
            before do
              TestConfig.override({
                broker_client_max_async_poll_duration_minutes: 90009
              })
              job.perform
            end

            it 'sets to the default value' do
              expect(job.maximum_duration_seconds).to eq(90009.minutes)
            end

            context 'when the plan defines a duration' do
              let(:maximum_polling_duration) { 7465 }

              it 'sets to the plan value' do
                expect(job.maximum_duration_seconds).to eq(7465)
              end
            end
          end

          context 'runs compatibility checks' do
            context 'volume mount' do
              let(:service_offering) { Service.make(requires: %w(volume_mount)) }

              it 'adds to the warnings required but disabled' do
                TestConfig.config[:volume_services_enabled] = false
                job.perform
                expect(job.warnings.to_json).to include(VCAP::CloudController::ServiceInstance::VOLUME_SERVICE_WARNING)
              end

              it 'does not warn if enabled' do
                TestConfig.config[:volume_services_enabled] = true
                job.perform
                expect(job.warnings).to be_empty
              end
            end

            context 'route forwarding' do
              let(:service_offering) { Service.make(requires: %w(route_forwarding)) }

              it 'adds to the warnings required but disabled' do
                TestConfig.config[:route_services_enabled] = false
                job.perform
                expect(job.warnings.to_json).to include(VCAP::CloudController::ServiceInstance::ROUTE_SERVICE_WARNING)
              end

              it 'does not warn if enabled' do
                TestConfig.config[:route_services_enabled] = true
                job.perform
                expect(job.warnings).to be_empty
              end
            end
          end

          it 'sends the operation request to the broker' do
            job.perform
            expect(job).to have_received(:send_broker_request).with(client)
          end

          context 'when sending the operation request fails' do
            before do
              allow_any_instance_of(FakeAsyncOperation).to receive(:send_broker_request).and_raise(RuntimeError, 'not today')
            end

            it 'raises the error and fails the last operation' do
              expect { job.perform }.to raise_error(RuntimeError, 'not today')

              expect(service_instance.last_operation.type).to eq(operation)
              expect(service_instance.last_operation.state).to eq('failed')
              expect(service_instance.last_operation.description).to eq('not today')
            end
          end

          context 'when the broker responds synchronously' do
            let(:operation_response) {
              { last_operation: { state: 'succeeded', type: operation } }
            }

            before do
              job.perform
            end

            it 'does not fetch last operation' do
              expect(client).not_to have_received(:fetch_service_instance_last_operation)
            end

            it 'finishes the job' do
              expect(job.finished).to eq(true)
            end

            it 'updates the service instance' do
              service_instance.reload

              expect(service_instance.last_operation.type).to eq(operation)
              expect(service_instance.last_operation.state).to eq('succeeded')
            end
          end

          context 'when the broker responds asynchronously' do
            let(:operation_response) {
              { last_operation: { state: 'in progress', type: operation, description: 'abc' } }
            }
            let(:last_operation_response) {
              { last_operation: { state: 'some state', type: operation } }
            }

            before do
              allow(client).to receive(:fetch_service_instance_last_operation).and_return(
                last_operation_response,
              )
              job.perform
            end

            it 'immediately fetches the last operation' do
              expect(client).to have_received(:fetch_service_instance_last_operation)
            end

            it 'updates the service instance state' do
              expect(service_instance.last_operation.type).to eq(operation)
              expect(service_instance.last_operation.state).to eq('some state')
            end

            it 'does not finish the job' do
              expect(job.finished).to eq(false)
            end
          end
        end

        context 'when it is re-executed' do
          let(:operation_response) {
            { last_operation: { state: 'in progress', type: operation } }
          }
          let(:last_operation_responses) {
            [{ last_operation: { state: 'in progress', type: operation } }]
          }

          before do
            allow(client).to receive(:fetch_service_instance_last_operation).and_return(
              *last_operation_responses
            )
            job.perform
          end

          context 'the maximum duration' do
            it 'recomputes the value' do
              job.maximum_duration_seconds = 90009
              TestConfig.override({ broker_client_max_async_poll_duration_minutes: 8088 })
              job.perform
              expect(job.maximum_duration_seconds).to eq(8088.minutes)
            end

            context 'when the plan value changes between calls' do
              before do
                job.maximum_duration_seconds = 90009
                service_plan.update(maximum_polling_duration: 5000)
                job.perform
              end

              it 'sets to the new plan value' do
                expect(job.maximum_duration_seconds).to eq(5000)
              end
            end
          end

          it 'does not send any operation request to the broker' do
            job.perform
            expect(job).to have_received(:send_broker_request).once
          end

          it 'fetches the last operation' do
            job.perform
            expect(client).to have_received(:fetch_service_instance_last_operation).with(service_instance).twice
          end
        end

        context 'fetching the last operation' do
          let(:operation_response) {
            { last_operation: { state: 'in progress', type: operation } }
          }
          let(:last_operation_responses) {
            [{ last_operation: { state: 'in progress', type: operation } }]
          }

          before do
            allow(client).to receive(:fetch_service_instance_last_operation).and_return(
              *last_operation_responses
            )
            job.perform
          end

          context 'when it returns success' do
            let(:last_operation_responses) {
              [
                { last_operation: { state: 'in progress', type: operation } },
                { last_operation: { state: 'succeeded', type: operation, description: 'done' } }
              ]
            }

            context 'and nothing raises before returning' do
              before do
                job.perform
              end

              it 'finishes the job' do
                expect(job.finished).to eq(true)
              end

              it 'updates the service instance last operation' do
                expect(service_instance.last_operation.type).to eq(operation)
                expect(service_instance.last_operation.state).to eq('succeeded')
                expect(service_instance.last_operation.description).to eq('done')
              end

              it 'records an audit event' do
                event = Event.find(type: 'audit.service_instance.fake-operation')
                expect(event).to be
                expect(event.actee).to eq(service_instance.guid)
                expect(event.metadata['request']).to have_key('some_data')
              end

              it 'executes the operation succeeded action' do
                expect(job).to have_received(:operation_succeeded)
              end
            end

            context 'when #operation_succeeded raises' do
              it 'fails the operation' do
                allow_any_instance_of(FakeAsyncOperation).to receive(:operation_succeeded).and_raise('failed oh no')

                expect { job.perform }.to raise_error('failed oh no')
                expect(service_instance.last_operation.type).to eq(operation)
                expect(service_instance.last_operation.state).to eq('failed')
                expect(service_instance.last_operation.description).to eq('failed oh no')
              end
            end
          end

          context 'when it returns a failure' do
            context 'and the operation type has not changed' do
              let(:last_operation_responses) {
                [
                  { last_operation: { state: 'in progress', type: operation } },
                  { last_operation: { state: 'failed', type: operation, description: 'im sorry' } }
                ]
              }

              it 'raises an error and updates the service instance last operation' do
                expect { job.perform }.to raise_error(
                  CloudController::Errors::ApiError,
                  /fake-operation could not be completed/
                )

                expect(service_instance.last_operation.type).to eq(operation)
                expect(service_instance.last_operation.state).to eq('failed')
                expect(service_instance.last_operation.description).to eq('im sorry')
              end

              context 'orphan mitigation' do
                before do
                  allow_any_instance_of(FakeAsyncOperation).to receive(:restart_on_failure?).and_return(true)
                end

                context 'when last operation does not fail with a 400 code' do
                  it 'does not raise an error' do
                    expect { job.perform }.not_to raise_error
                  end

                  it 'does not update the last operation' do
                    job.perform

                    expect(service_instance.last_operation.type).to eq(operation)
                    expect(service_instance.last_operation.state).to eq('in progress')
                  end

                  it 'retries the operation' do
                    job.perform
                    job.perform
                    expect(job).to have_received(:send_broker_request).twice
                  end

                  it 'raises an error and updates the last operation after MAX_RETRIES' do
                    (0...ServiceInstanceAsyncJob::MAX_RETRIES - 1).each do
                      expect { job.perform }.not_to raise_error
                    end

                    expect { job.perform }.to raise_error(
                      CloudController::Errors::ApiError,
                      /fake-operation could not be completed/
                    )
                    expect(job).to have_received(:send_broker_request).exactly(3).times

                    expect(service_instance.last_operation.type).to eq(operation)
                    expect(service_instance.last_operation.state).to eq('failed')
                    expect(service_instance.last_operation.description).to eq('im sorry')
                  end
                end

                context 'when last operation fails with a 400 code' do
                  let(:last_operation_responses) {
                    [
                      { last_operation: { state: 'in progress', type: operation } },
                      {
                        last_operation: { state: 'failed', type: operation, description: 'im sorry' },
                        http_status_code: 400
                      }
                    ]
                  }

                  it 'raises without attempting to run the orphan mitigation' do
                    expect { job.perform }.to raise_error(
                      CloudController::Errors::ApiError,
                      /fake-operation could not be completed/
                    )

                    expect(service_instance.last_operation.type).to eq(operation)
                    expect(service_instance.last_operation.state).to eq('failed')
                    expect(service_instance.last_operation.description).to include('im sorry')
                  end
                end
              end
            end

            context 'but the operation type has changed' do
              let(:last_operation_responses) {
                [
                  { last_operation: { state: 'in progress', type: operation } },
                  { last_operation: { state: 'in progress', type: operation } },
                  { last_operation: { state: 'failed', type: 'another-operation', description: 'im sorry' } }
                ]
              }

              it 'raises when retried' do
                expect { job.perform }.not_to raise_error
                expect { job.perform }.to raise_error(
                  CloudController::Errors::ApiError,
                  /fake-operation could not be completed/
                )
              end
            end
          end

          context 'when it returns in progress' do
            let(:last_operation_responses) {
              [
                { last_operation: { state: 'in progress', type: operation } },
                { last_operation: { state: 'in progress', type: operation, description: 'done' } },
              ]
            }

            before do
              job.perform
            end

            it 'does not finishes the job' do
              expect(job.finished).to eq(false)
            end
          end

          context 'when retry_after is returned in the broker response' do
            let(:last_operation_responses) {
              [
                {
                  last_operation: { state: 'in progress', type: operation },
                  retry_after: 95
                },
                {
                  last_operation: { state: 'in progress', type: operation },
                  retry_after: 180
                },
              ]
            }

            it 'updates the polling interval' do
              expect(job.polling_interval_seconds).to eq(95)
              job.perform
              expect(job.polling_interval_seconds).to eq(180)
            end
          end

          context 'when the description is long (mysql)' do
            let(:long_description) { '123' * 512 }
            let(:last_operation_responses) {
              [{ last_operation: { state: 'in progress', type: operation, description: long_description } }]
            }

            it 'updates the description' do
              expect(service_instance.last_operation.description).to eq(long_description)
            end
          end

          context 'when there is no description' do
            let(:last_operation_responses) {
              [
                { last_operation: { state: 'in progress', type: operation, description: 'abc' } },
                { last_operation: { state: 'in progress', type: operation } }
              ]
            }

            it 'leaves the original description' do
              expect(service_instance.last_operation.description).to eq('abc')
              job.perform
              expect(service_instance.reload.last_operation.description).to eq('abc')
            end
          end

          context 'when the client raises' do
            before do
              allow(client).to receive(:fetch_service_instance_last_operation).and_raise(err)
            end

            context 'due to a HttpRequestError' do
              let(:err) { HttpRequestError.new('oops', 'uri', 'GET', RuntimeError.new) }

              it 'does not fail de job' do
                expect { job.perform }.not_to raise_error
              end

              it 'logs the error' do
                job.perform
                expect(logger).to have_received(:error).with(/There was an error while fetching the service instance operation state/)
              end
            end

            context 'due to a HttpResponseError' do
              let(:err) { HttpResponseError.new('message', :put, double(code: 500, reason: '', body: '')) }

              it 'does not fail the job' do
                expect { job.perform }.not_to raise_error
              end

              it 'logs the error' do
                job.perform
                expect(logger).to have_received(:error).with(/There was an error while fetching the service instance operation state/)
              end
            end

            context 'due to an unexpected error' do
              let(:err) { RuntimeError.new('what') }

              it 'fails the job' do
                expect { job.perform }.to raise_error(RuntimeError, /what/)
              end
            end
          end

          context 'when saving the service instance state fails due to Sequel Errors' do
            before do
              allow_any_instance_of(VCAP::CloudController::ManagedServiceInstance).
                to receive(:save_and_update_operation).and_raise(Sequel::Error.new('foo'))
            end

            it 'does not fail the job' do
              expect { job.perform }.not_to raise_error
            end

            it 'logs the error' do
              job.perform
              expect(logger).to have_received(:error).with(/There was an error while fetching the service instance operation state/)
            end
          end

          context 'when timeout is reached' do
            let(:last_operation_responses) {
              [
                { last_operation: { state: 'in progress', type: operation } },
                { last_operation: { state: 'in progress', type: operation } }
              ]
            }

            it 'fails the job and update the service instance' do
              Timecop.freeze(Time.now + job.maximum_duration_seconds + 1) do
                Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic).enqueue_pollable
                execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
                expect(service_instance.last_operation.type).to eq('fake-operation')
                expect(service_instance.last_operation.state).to eq('failed')
                expect(service_instance.last_operation.description).to eq('Service Broker failed to fakeoperation within the required time.')
              end
            end

            context 'and the plan has a maximum duration' do
              let(:maximum_polling_duration) { 4321 }

              it 'fails the job and update the service instance' do
                Timecop.freeze(Time.now + 4321 + 1) do
                  Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic).enqueue_pollable
                  execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
                  expect(service_instance.last_operation.type).to eq('fake-operation')
                  expect(service_instance.last_operation.state).to eq('failed')
                  expect(service_instance.last_operation.description).to eq('Service Broker failed to fakeoperation within the required time.')
                end
              end
            end
          end
        end
      end

      describe '#handle_timeout' do
        it 'updates the service instance last operation' do
          job.handle_timeout
          expect(service_instance.last_operation.type).to eq(operation)
          expect(service_instance.last_operation.state).to eq('failed')
          expect(service_instance.last_operation.description).to eq('Service Broker failed to fakeoperation within the required time.')
        end
      end

      describe '#job_name_in_configuration' do
        it 'returns the job name' do
          expect(job.job_name_in_configuration).to eq('service_instance_fake-operation')
        end
      end

      describe '#max_attempts' do
        it 'returns 1' do
          expect(job.max_attempts).to eq(1)
        end
      end

      describe '#resource_type' do
        it 'returns "service_instances"' do
          expect(job.resource_type).to eq('service_instances')
        end
      end

      describe '#resource_guid' do
        it 'returns the service instance guid' do
          expect(job.resource_guid).to eq(service_instance.guid)
        end
      end

      describe '#display_name' do
        it 'returns the display name' do
          expect(job.display_name).to eq('service_instance.fake-operation')
        end
      end

      describe '#restart_in_failures?' do
        it 'is false by default' do
          expect(job.restart_on_failure?).to eq(false)
        end
      end
    end
  end
end
