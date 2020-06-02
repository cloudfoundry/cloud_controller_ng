require 'spec_helper'
require 'jobs/v3/update_service_instance_job'
require 'cloud_controller/errors/api_error'

module VCAP
  module CloudController
    module V3
      RSpec.describe UpdateServiceInstanceJob do
        it_behaves_like 'delayed job', described_class

        let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }
        let(:org) { Organization.make }
        let(:space) { Space.make(organization: org) }
        let(:service_offering) { Service.make }
        let(:maximum_polling_duration) { nil }
        let(:metadata) do
          {
            labels: {
              foo: 'bar',
              'pre.fix/to_delete': nil,
            },
            annotations: {
              baz: 'quz',
              'pre.fix/to_delete': nil,
            }
          }
        end
        let(:original_service_plan) { ServicePlan.make(service: service_offering, maximum_polling_duration: maximum_polling_duration) }
        let(:new_service_plan) { ServicePlan.make(service: service_offering, maximum_polling_duration: maximum_polling_duration) }
        let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'foo@example.com') }
        let(:request_attr) { { dummy_data: 'dummy_data' } }
        let(:name) { Sham.name }
        let(:tags) { %w(baz quz) }

        let(:service_instance) do
          service_instance = ManagedServiceInstance.new
          service_instance.save_with_new_operation(
            {
              name: name,
              tags: tags,
              space_guid: space.guid,
              service_plan: original_service_plan,
            },
            {
              type: 'update',
              state: ManagedServiceInstance::IN_PROGRESS_STRING
            }
          )
          service_instance.label_ids = [
            VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
            VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
          ]
          service_instance.annotation_ids = [
            VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
            VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
          ]
          service_instance.reload
        end

        let(:message) do
          ServiceInstanceUpdateManagedMessage.new({
            name: 'new-name',
            tags: %w(foo bar),
            parameters: request_attr,
            relationships: {
              service_plan: {
                data: {
                  guid: new_service_plan.guid
                }
              }
            },
            metadata: metadata,
          })
        end

        let(:job) do
          UpdateServiceInstanceJob.new(
            service_instance.guid,
            message: message,
            user_audit_info: user_audit_info
          )
        end

        def run_job(job, jobs_succeeded: 1, jobs_failed: 0, jobs_to_execute: 100)
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

        it 'raises if the service instance no longer exists' do
          service_instance.destroy
          run_job(job, jobs_succeeded: 0, jobs_failed: 1)

          pollable_job = PollableJobModel.last
          expect(pollable_job.resource_guid).to eq(service_instance.guid)
          expect(pollable_job.state).to eq(PollableJobModel::FAILED_STATE)
          expect(pollable_job.cf_api_error).not_to be_nil
          error = YAML.safe_load(pollable_job.cf_api_error)
          expect(error['errors'].first['code']).to eq(60004)
          expect(error['errors'].first['detail']).
            to include('The service instance could not be found')
        end

        it 'raises if `last_operation` is not `update`' do
          service_instance.save_with_new_operation({}, { type: 'create' })
          run_job(job, jobs_succeeded: 0, jobs_failed: 1)

          expect(service_instance.reload.last_operation.type).to eq('create')

          pollable_job = PollableJobModel.last
          expect(pollable_job.resource_guid).to eq(service_instance.guid)
          expect(pollable_job.state).to eq(PollableJobModel::FAILED_STATE)
          expect(pollable_job.cf_api_error).not_to be_nil
          error = YAML.safe_load(pollable_job.cf_api_error)
          expect(error['errors'].first['code']).to eq(10009)
          expect(error['errors'].first['detail']).
            to include('Update could not be completed: delete in progress')
        end

        context 'when the broker client response is synchronous' do
          let(:broker_update_response) {
            {
              instance: { dashboard_url: 'example.foo' },
              last_operation: {
                type: 'update',
                state: 'succeeded',
                description: 'abc',
              }
            }
          }

          before do
            allow(client).to receive(:update).and_return([broker_update_response, nil])
            run_job(job, jobs_succeeded: 1)
          end

          it 'receives the correct parameters' do
            expect(client).to have_received(:update).with(
              service_instance,
              new_service_plan,
              accepts_incomplete: false,
              arbitrary_parameters: request_attr,
              previous_values: {
                plan_id: original_service_plan.broker_provided_id,
                service_id: service_offering.broker_provided_id,
                organization_id: org.guid,
                space_id: space.guid,
              },
              name: 'new-name',
            )
          end

          it 'updates the last operation' do
            expect(service_instance.last_operation.type).to eq('update')
            expect(service_instance.last_operation.state).to eq('succeeded')
            expect(service_instance.last_operation.description).to eq('abc')
          end

          it 'updates the service instance' do
            service_instance.reload
            expect(service_instance.name).to eq('new-name')
            expect(service_instance.tags).to eq(%w(foo bar))
            expect(service_instance.service_plan).to eq(new_service_plan)

            expect(service_instance.labels.map { |l| { prefix: l.key_prefix, key: l.key_name, value: l.value } }).to match_array([
              { prefix: nil, key: 'foo', value: 'bar' },
              { prefix: 'pre.fix', key: 'tail', value: 'fluffy' },
            ])
            expect(service_instance.annotations.map { |a| { prefix: a.key_prefix, key: a.key, value: a.value } }).to match_array([
              { prefix: nil, key: 'baz', value: 'quz' },
              { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
            ])
          end

          it 'updates the job' do
            pollable_job = PollableJobModel.last
            expect(pollable_job.resource_guid).to eq(service_instance.guid)
            expect(pollable_job.state).to eq(PollableJobModel::COMPLETE_STATE)
          end

          it 'creates an audit event' do
            event = Event.find(type: 'audit.service_instance.update')
            expect(event).to be
            expect(event.actee).to eq(service_instance.guid)
            expect(event.metadata['request']).to have_key('name')
            expect(event.metadata['request']).to have_key('parameters')
            expect(event.metadata['request']).to have_key('tags')
            expect(event.metadata['request']).to have_key('metadata')
            expect(event.metadata['request']).to have_key('relationships')
          end
        end

        context 'when the broker client returns an error' do
          before do
            allow(client).to receive(:update).and_return([
              {
                last_operation: {
                  state: 'failed',
                  type: 'update',
                  description: 'something bad happened'
                }
              },
              StandardError.new('something bad happened')
            ])
          end

          it 'updates the instance status to update failed' do
            run_job(job, jobs_succeeded: 0, jobs_failed: 1)

            service_instance.reload

            expect(service_instance.operation_in_progress?).to eq(false)
            expect(service_instance.last_operation.type).to eq('update')
            expect(service_instance.last_operation.state).to eq('failed')
          end

          it 'updates the pollable job status to failed' do
            pollable_job = run_job(job, jobs_succeeded: 0, jobs_failed: 1)
            pollable_job.reload
            expect(pollable_job.state).to eq(PollableJobModel::FAILED_STATE)
          end

          it 'retains the existing service instance attributes' do
            run_job(job, jobs_succeeded: 0, jobs_failed: 1)

            service_instance.reload

            expect(service_instance.name).to eq(name)
            expect(service_instance.tags).to eq(tags)
            expect(service_instance.service_plan).to eq(original_service_plan)

            expect(service_instance.labels.map { |l| { prefix: l.key_prefix, key: l.key_name, value: l.value } }).to match_array([
              { prefix: 'pre.fix', key: 'to_delete', value: 'value' },
              { prefix: 'pre.fix', key: 'tail', value: 'fluffy' },
            ])
            expect(service_instance.annotations.map { |a| { prefix: a.key_prefix, key: a.key, value: a.value } }).to match_array([
              { prefix: 'pre.fix', key: 'to_delete', value: 'value' },
              { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
            ])
          end
        end

        context 'when there is an error updating the DB' do
          let(:broker_update_response) {
            {
              instance: { dashboard_url: 'example.foo' },
              last_operation: {
                type: 'update',
                state: 'succeeded',
                description: 'abc',
              }
            }
          }

          before do
            allow(client).to receive(:update).and_return([broker_update_response, nil])
            allow(MetadataUpdate).to receive(:update).and_raise(StandardError.new('boom'))
          end

          it 'updates the pollable job status to failed' do
            pollable_job = run_job(job, jobs_succeeded: 0, jobs_failed: 1)
            pollable_job.reload
            expect(pollable_job.state).to eq(PollableJobModel::FAILED_STATE)
          end

          it 'updates the instance status to update failed' do
            run_job(job, jobs_succeeded: 0, jobs_failed: 1)

            service_instance.reload

            expect(service_instance.operation_in_progress?).to eq(false)
            expect(service_instance.last_operation.type).to eq('update')
            expect(service_instance.last_operation.state).to eq('failed')
            expect(service_instance.last_operation.description).to eq('boom')
          end
        end

        describe 'volume mount and route service checks' do
          let(:broker_update_response) {
            {
              instance: { dashboard_url: 'example.foo' },
              last_operation: {
                type: 'update',
                state: 'succeeded',
                description: 'abc',
              }
            }
          }

          before do
            allow(client).to receive(:update).and_return(broker_update_response)
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
