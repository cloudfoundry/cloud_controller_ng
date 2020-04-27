require 'spec_helper'
require 'jobs/v3/services/create_service_instance_job'
require 'cloud_controller/errors/api_error'

module VCAP
  module CloudController
    module V3
      RSpec.describe CreateServiceInstanceJob do
        it_behaves_like 'delayed job', described_class

        let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }
        let(:space) { Space.make }
        let(:service_offering) { Service.make }
        let(:service_plan) { ServicePlan.make(service: service_offering) }
        let(:new_service_plan) { ServicePlan.make }
        let(:service_instance_attr) {
          {
            name: Sham.name,
            space_guid: space.guid,
            service_plan: new_service_plan,
          }
        }
        let(:last_operation) {
          {
            type: 'create',
            state: ManagedServiceInstance::IN_PROGRESS_STRING
          }
        }
        let(:service_instance) do
          operation = ServiceInstanceOperation.make(proposed_changes: {
            name: 'new-fake-name',
            service_plan_guid: new_service_plan.guid
          })
          operation.save
          service_instance = ManagedServiceInstance.make(service_plan: service_plan)
          service_instance.save

          service_instance.service_instance_operation = operation
          service_instance
        end

        let(:user) { User.make }
        let(:user_email) { 'foo@example.com' }
        let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
        let(:request_attr) {
          {
            dummy_data: 'dummy_data'
          }
        }
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

        context 'when broker returns `in progress` on the provision request' do
          let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }
          let(:broker_provision_response) {
            {
              instance: { dashboard_url: 'example.foo' },
              last_operation: { type: 'create',
                               state: 'in progress',
                               description: '',
                               broker_provided_operation: 'task1' }
            }
          }
          let(:in_progress_last_operation) { { last_operation: { state: 'in progress', description: '123' } } }

          before do
            allow(client).to receive(:provision).and_return(broker_provision_response)
            allow(client).to receive(:fetch_service_instance_last_operation).and_return(in_progress_last_operation)
          end

          it 'enqueues a fetch last operation job' do
            run_job(job, jobs_succeeded: 2)

            expect(Delayed::Job.count).to eq 1
            expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(FetchLastOperationJob)
          end

          it 'updates the pollable job status to polling' do
            pollable_job = run_job(job, jobs_succeeded: 2)
            pollable_job.reload
            expect(pollable_job.state).to eq(PollableJobModel::POLLING_STATE)
          end

          it 'sets the service instance state to `create in progress`' do
            run_job(job, jobs_succeeded: 2)

            service_instance.reload

            expect(service_instance.operation_in_progress?).to eq(true)
            expect(service_instance.terminal_state?).to eq(false)
            expect(service_instance.last_operation.type).to eq('create')
            expect(service_instance.last_operation.state).to eq('in progress')
          end

          it 'does not create an audit event`' do
            run_job(job, jobs_succeeded: 1, jobs_to_execute: 1)

            expect(Event.find(type: 'audit.service_instance.create')).to be_nil
          end
        end

        context 'when broker returns `succeeded` on the provision request' do
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

          it 'does not run any extra job' do
            run_job(job, jobs_succeeded: 1)

            expect(Delayed::Job.count).to eq 0
          end

          it 'updates the pollable job status to complete' do
            pollable_job = run_job(job, jobs_succeeded: 1)
            pollable_job.reload
            expect(pollable_job.state).to eq(PollableJobModel::COMPLETE_STATE)
          end

          it 'sets the service instance state to `create succeeded`' do
            run_job(job, jobs_succeeded: 1)

            service_instance.reload

            expect(service_instance.operation_in_progress?).to eq(false)
            expect(service_instance.terminal_state?).to eq(true)
            expect(service_instance.last_operation.type).to eq('create')
            expect(service_instance.last_operation.state).to eq('succeeded')
          end

          it 'creates an audit event' do
            run_job(job, jobs_succeeded: 1)

            event = Event.find(type: 'audit.service_instance.create')
            expect(event).to be
            expect(event.actee).to eq(service_instance.guid)
            expect(event.metadata['request']).to have_key('dummy_data')
          end
        end

        context 'when the broker client raises during provision' do
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
