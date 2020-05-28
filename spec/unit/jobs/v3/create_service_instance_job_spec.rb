require 'spec_helper'
require 'jobs/v3/create_service_instance_job'
require 'cloud_controller/errors/api_error'

module VCAP
  module CloudController
    module V3
      RSpec.describe CreateServiceInstanceJob do
        it_behaves_like 'delayed job', described_class

        let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }
        let(:service_offering) { Service.make }
        let(:maximum_polling_duration) { nil }
        let(:service_plan) { ServicePlan.make(service: service_offering, maximum_polling_duration: maximum_polling_duration) }
        let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'foo@example.com') }
        let(:request_attr) { { dummy_data: 'dummy_data' } }
        let(:service_instance) do
          service_instance = ManagedServiceInstance.new
          service_instance.save_with_new_operation(
            {
              name: Sham.name,
              space_guid: Space.make.guid,
              service_plan: service_plan,
            },
            {
              type: 'create',
              state: ManagedServiceInstance::IN_PROGRESS_STRING
            }
          )
          service_instance.reload
        end

        let(:job) do
          CreateServiceInstanceJob.new(
            service_instance.guid,
            arbitrary_parameters: request_attr,
            user_audit_info: user_audit_info,
          )
        end

        def run_job(job, jobs_succeeded: 2, jobs_failed: 0, jobs_to_execute: 100)
          pollable_job = Jobs::Enqueuer.new(job, { queue: Jobs::Queues.generic, run_at: Delayed::Job.db_time_now }).enqueue_pollable
          execute_all_jobs(expected_successes: jobs_succeeded, expected_failures: jobs_failed, jobs_to_execute: jobs_to_execute)
          pollable_job
        end

        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        end

        after do
          Timecop.return
        end

        context 'when the broker response is synchronous' do
          let(:broker_provision_response) {
            {
              instance: { dashboard_url: 'example.foo' },
              last_operation: {
                type: 'create',
                state: 'succeeded',
                description: 'abc',
              }
            }
          }

          before do
            allow(client).to receive(:provision).and_return(broker_provision_response)
            run_job(job, jobs_succeeded: 1)
          end

          it 'asks the client to provision the service instance' do
            expect(client).to have_received(:provision).with(
              service_instance,
              accepts_incomplete: true,
              arbitrary_parameters: request_attr,
              maintenance_info: service_plan.maintenance_info,
            )
          end

          it 'updates the database' do
            expect(service_instance.last_operation.type).to eq('create')
            expect(service_instance.last_operation.state).to eq('succeeded')
            expect(service_instance.last_operation.description).to eq('abc')

            pollable_job = PollableJobModel.last
            expect(pollable_job.resource_guid).to eq(service_instance.guid)
            expect(pollable_job.state).to eq(PollableJobModel::COMPLETE_STATE)
          end

          it 'creates an audit event' do
            event = Event.find(type: 'audit.service_instance.create')
            expect(event).to be
            expect(event.actee).to eq(service_instance.guid)
            expect(event.metadata['request']).to have_key('dummy_data')
          end
        end

        context 'when the broker response is asynchronous' do
          let(:broker_provision_response) {
            {
              instance: { dashboard_url: 'example.foo' },
              last_operation: {
                type: 'create',
                state: 'in progress',
                description: '123',
                broker_provided_operation: 'task1',
              }
            }
          }

          let(:in_progress_last_operation) { { last_operation: { state: 'in progress' } } }

          before do
            allow(client).to receive(:provision).and_return(broker_provision_response)
            allow(client).to receive(:fetch_service_instance_last_operation).and_return(in_progress_last_operation)
            run_job(job, jobs_succeeded: 1, jobs_to_execute: 1)
          end

          it 'asks the client to provision the service instance' do
            expect(client).to have_received(:provision).with(
              service_instance,
              accepts_incomplete: true,
              arbitrary_parameters: request_attr,
              maintenance_info: service_plan.maintenance_info,
            )
          end

          it 'immediately asks for a progress update' do
            expect(client).to have_received(:fetch_service_instance_last_operation).with(service_instance)
          end

          it 'updates the database' do
            expect(service_instance.last_operation.type).to eq('create')
            expect(service_instance.last_operation.state).to eq('in progress')
            expect(service_instance.last_operation.description).to eq('123')

            pollable_job = PollableJobModel.last
            expect(pollable_job.resource_guid).to eq(service_instance.guid)
            expect(pollable_job.state).to eq(PollableJobModel::POLLING_STATE)
          end

          context 'when a retry_after header is returned' do
            let(:in_progress_last_operation) do
              {
                last_operation: { state: 'in progress', description: '123' },
                retry_after: 430,
              }
            end

            it 'updates the polling interval' do
              Timecop.freeze(Time.now + 420.seconds) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              Timecop.freeze(Time.now + 440.seconds) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end
          end

          context 'polling the last operation' do
            let(:description) { 'doing stuff' }

            let(:in_progress_last_operation_2) { { last_operation: { state: 'in progress', description: 'doing stuff' } } }

            before do
              allow(client).to receive(:fetch_service_instance_last_operation).and_return(in_progress_last_operation_2)

              Timecop.travel(job.polling_interval_seconds + 1.second)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
            end

            it 'calls the last operation endpoint only' do
              expect(client).to have_received(:provision).once
              expect(client).to have_received(:fetch_service_instance_last_operation).twice
            end

            it 'updates the description' do
              expect(service_instance.last_operation.description).to eq('doing stuff')
            end

            context 'when there is no description' do
              let(:in_progress_last_operation_2) { { last_operation: { state: 'in progress' } } }

              it 'leaves the original description' do
                expect(service_instance.last_operation.description).to eq('123')
              end
            end

            context 'when the description is long (mysql)' do
              let(:long_description) { '123' * 512 }
              let(:in_progress_last_operation_2) { { last_operation: { state: 'in progress', description: long_description } } }

              it 'updates the description' do
                expect(service_instance.last_operation.description).to eq(long_description)
              end
            end
          end

          context 'when provisioning has succeeded' do
            let(:succeeded_last_operation) { { last_operation: { state: 'succeeded', description: '789' } } }

            before do
              Timecop.travel(job.polling_interval_seconds + 1.second)
              allow(client).to receive(:fetch_service_instance_last_operation).and_return(succeeded_last_operation)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
            end

            it 'updates the database' do
              expect(service_instance.last_operation.type).to eq('create')
              expect(service_instance.last_operation.state).to eq('succeeded')
              expect(service_instance.last_operation.description).to eq('789')

              pollable_job = PollableJobModel.last
              expect(pollable_job.resource_guid).to eq(service_instance.guid)
              expect(pollable_job.state).to eq(PollableJobModel::COMPLETE_STATE)
            end

            it 'creates an audit event' do
              event = Event.find(type: 'audit.service_instance.create')
              expect(event).to be
              expect(event.actee).to eq(service_instance.guid)
              expect(event.metadata['request']).to have_key('dummy_data')
            end
          end

          context 'when provisioning has failed' do
            let(:succeeded_last_operation) { { last_operation: { state: 'failed', description: 'oops' } } }

            before do
              Timecop.travel(job.polling_interval_seconds + 1.second)
              allow(client).to receive(:fetch_service_instance_last_operation).and_return(succeeded_last_operation)
              execute_all_jobs(expected_successes: 0, expected_failures: 1)
            end

            it 'updates the database' do
              expect(service_instance.last_operation.type).to eq('create')
              expect(service_instance.last_operation.state).to eq('failed')
              expect(service_instance.last_operation.description).to eq('oops')

              pollable_job = PollableJobModel.last
              expect(pollable_job.resource_guid).to eq(service_instance.guid)
              expect(pollable_job.state).to eq(PollableJobModel::FAILED_STATE)
              expect(pollable_job.cf_api_error).not_to be_nil
              error = YAML.safe_load(pollable_job.cf_api_error)
              expect(error['errors'].first['code']).to eq(60030)
              expect(error['errors'].first['detail']).
                to include('The service broker reported an error during provisioning: oops')
            end

            it 'does not create an audit event' do
              event = Event.find(type: 'audit.service_instance.create')
              expect(event).to be_nil
            end
          end

          context 'timing out' do
            it 'marks the service instance creation as failed' do
              Timecop.freeze(Time.now + job.maximum_duration_seconds) do
                execute_all_jobs(expected_successes: 0, expected_failures: 1)

                expect(service_instance.last_operation.type).to eq('create')
                expect(service_instance.last_operation.state).to eq('failed')
                expect(service_instance.last_operation.description).to eq('Service Broker failed to provision within the required time.')
              end
            end

            context 'when the plan has a maximum duration' do
              let(:maximum_polling_duration) { 4242 }

              it 'uses it' do
                Timecop.freeze(Time.now + 4242) do
                  execute_all_jobs(expected_successes: 0, expected_failures: 1)

                  expect(service_instance.last_operation.type).to eq('create')
                  expect(service_instance.last_operation.state).to eq('failed')
                  expect(service_instance.last_operation.description).to eq('Service Broker failed to provision within the required time.')
                end
              end
            end
          end

          context 'when the service instance is removed while create is in progress' do
            before do
              service_instance.destroy
            end

            it 'fails the job' do
              Timecop.travel(job.polling_interval_seconds + 1.second)
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              pollable_job = PollableJobModel.last
              expect(pollable_job.resource_guid).to eq(service_instance.guid)
              expect(pollable_job.state).to eq(PollableJobModel::FAILED_STATE)
              expect(pollable_job.cf_api_error).not_to be_nil
              error = YAML.safe_load(pollable_job.cf_api_error)
              expect(error['errors'].first['code']).to eq(60004)
              expect(error['errors'].first['detail']).
                to include('The service instance could not be found')
            end
          end

          context 'when the service instance deletion is started while create is in progress' do
            before do
              service_instance.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
            end

            it 'fails the job' do
              Timecop.travel(job.polling_interval_seconds + 1.second)
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              pollable_job = PollableJobModel.last
              expect(pollable_job.resource_guid).to eq(service_instance.guid)
              expect(pollable_job.state).to eq(PollableJobModel::FAILED_STATE)
              expect(pollable_job.cf_api_error).not_to be_nil
              error = YAML.safe_load(pollable_job.cf_api_error)
              expect(error['errors'].first['code']).to eq(10009)
              expect(error['errors'].first['detail']).
                to eq('Create could not be completed: delete in progress')
            end
          end

          context 'when fetching the last operation from the broker fails' do
            context 'due to an HttpRequestError' do
              before do
                err = HttpRequestError.new('oops', 'uri', 'GET', RuntimeError.new)
                allow(client).to receive(:fetch_service_instance_last_operation).and_raise(err)
              end

              it 'should continue' do
                Timecop.travel(job.polling_interval_seconds + 1.second)
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                expect(Delayed::Job.count).to eq 1
              end
            end

            context 'due to an HttpResponseError' do
              before do
                response = VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: 412, body: {})
                err = HttpResponseError.new('oops', 'GET', response)
                allow(client).to receive(:fetch_service_instance_last_operation).and_raise(err)
              end

              it 'should continue' do
                Timecop.travel(job.polling_interval_seconds + 1.second)
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                expect(Delayed::Job.count).to eq 1
              end
            end
          end

          context 'when saving the last operation to the database fails' do
            before do
              allow_any_instance_of(VCAP::CloudController::ManagedServiceInstance).
                to receive(:save_and_update_operation).and_raise(Sequel::Error.new('foo'))
            end

            it 'should continue' do
              Timecop.travel(job.polling_interval_seconds + 1.second)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(Delayed::Job.count).to eq 1
            end
          end
        end

        context 'when the broker client raises' do
          before do
            allow(client).to receive(:provision).and_raise('Oh no')
          end

          it 'updates the instance status to create failed' do
            run_job(job, jobs_succeeded: 0, jobs_failed: 1)

            service_instance.reload

            expect(service_instance.operation_in_progress?).to eq(false)
            expect(service_instance.terminal_state?).to eq(true)
            expect(service_instance.last_operation.type).to eq('create')
            expect(service_instance.last_operation.state).to eq('failed')
          end

          it 'updates the pollable job status to failed' do
            pollable_job = run_job(job, jobs_succeeded: 0, jobs_failed: 1)
            pollable_job.reload
            expect(pollable_job.state).to eq(PollableJobModel::FAILED_STATE)
          end
        end

        describe 'volume mount and route service checks' do
          let(:broker_provision_response) {
            {
              instance: { dashboard_url: 'example.foo' },
              last_operation: { type: 'create',
                state: 'succeeded',
                description: '' }
            }
          }
          before do
            allow(client).to receive(:provision).and_return(broker_provision_response)
          end

          context 'when volume mount required' do
            let(:service_offering) { Service.make(requires: %w(volume_mount)) }

            context 'volume mount disabled' do
              before do
                TestConfig.config[:volume_services_enabled] = false
              end

              it 'warns' do
                pollable_job = run_job(job, jobs_succeeded: 1)
                pollable_job.reload

                expect(pollable_job.warnings.to_json).to include(VCAP::CloudController::ServiceInstance::VOLUME_SERVICE_WARNING)
              end
            end

            context 'volume mount enabled' do
              before do
                TestConfig.config[:volume_services_enabled] = true
              end

              it 'does not warn' do
                pollable_job = run_job(job, jobs_succeeded: 1)
                pollable_job.reload

                expect(pollable_job.warnings).to be_empty
              end
            end
          end

          context 'when route forwarding required' do
            let(:service_offering) { Service.make(requires: %w(route_forwarding)) }

            context 'route forwarding disabled' do
              before do
                TestConfig.config[:route_services_enabled] = false
              end

              it 'warns' do
                pollable_job = run_job(job, jobs_succeeded: 1)
                pollable_job.reload

                expect(pollable_job.warnings.to_json).to include(VCAP::CloudController::ServiceInstance::ROUTE_SERVICE_WARNING)
              end
            end

            context 'route forwarding enabled' do
              before do
                TestConfig.config[:route_services_enabled] = true
              end

              it 'does not warn' do
                pollable_job = run_job(job, jobs_succeeded: 1)
                pollable_job.reload

                expect(pollable_job.warnings).to be_empty
              end
            end
          end
        end
      end
    end
  end
end
