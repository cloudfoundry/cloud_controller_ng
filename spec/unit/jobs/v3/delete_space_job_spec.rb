require 'spec_helper'
require 'jobs/v3/delete_space_job'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteSpaceJob do
      let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'test@example.com', user_name: 'test-user') }
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org, name: 'my-space') }

      subject(:job) { DeleteSpaceJob.new(space.guid, user_audit_info) }

      it_behaves_like 'delayed job', described_class

      describe '#perform' do
        context 'when the space does not exist' do
          before { space.destroy }

          it 'finishes the job' do
            job.perform
            expect(job.finished).to be(true)
          end
        end

        context 'when the space has no resources' do
          it 'deletes the space and finishes in single cycle' do
            job.perform
            expect(job.finished).to be(true)
            expect(Space.find(guid: space.guid)).to be_nil
          end
        end

        context 'when the space has apps without service bindings' do
          before do
            AppModel.make(space: space, name: 'app-1')
            AppModel.make(space: space, name: 'app-2')
          end

          it 'deletes all apps and the space in single cycle' do
            job.perform
            expect(job.finished).to be(true)
            expect(Space.find(guid: space.guid)).to be_nil
            expect(AppModel.where(space_guid: space.guid).count).to eq(0)
          end
        end

        context 'when the space has apps with async service bindings' do
          let(:app_model) { AppModel.make(space: space, name: 'bound-app') }

          before do
            app_model # ensure it's created
            allow_any_instance_of(AppDelete).to receive(:delete).and_raise(
              AppDelete::SubResourceError.new([AppDelete::AsyncBindingDeletionsTriggered.new('async binding in progress')])
            )
          end

          it 'stops the app on first cycle' do
            pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)
            # Simulate that BindingsDeleteMixin enqueued a child job with root_job_guid
            PollableJobModel.create(
              delayed_job_guid: SecureRandom.uuid,
              state: PollableJobModel::PROCESSING_STATE,
              operation: 'service_bindings.delete',
              resource_guid: 'some-binding-guid',
              resource_type: 'service_bindings',
              root_job_guid: pollable_job.guid
            )
            job.perform
            app_model.reload
            expect(app_model.desired_state).to eq(ProcessModel::STOPPED)
          end

          it 'does not finish on first cycle' do
            pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)
            PollableJobModel.create(
              delayed_job_guid: SecureRandom.uuid,
              state: PollableJobModel::PROCESSING_STATE,
              operation: 'service_bindings.delete',
              resource_guid: 'some-binding-guid',
              resource_type: 'service_bindings',
              root_job_guid: pollable_job.guid
            )
            job.perform
            expect(job.finished).to be(false)
          end

          it 'sets a warning when async operations are detected' do
            pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)
            PollableJobModel.create(
              delayed_job_guid: SecureRandom.uuid,
              state: PollableJobModel::PROCESSING_STATE,
              operation: 'service_bindings.delete',
              resource_guid: 'some-binding-guid',
              resource_type: 'service_bindings',
              root_job_guid: pollable_job.guid
            )
            job.perform
            expect(job.warnings).to include(
              hash_including(detail: a_string_matching(/Deletion in progress/))
            )
          end
        end

        context 'when the space has managed service instances (sync broker)' do
          let!(:service_instance) { ManagedServiceInstance.make(space: space, name: 'my-si') }

          before do
            stub_deprovision(service_instance, accepts_incomplete: true)
          end

          it 'deletes the SI and the space in single cycle' do
            job.perform
            expect(job.finished).to be(true)
            expect(Space.find(guid: space.guid)).to be_nil
            expect(ManagedServiceInstance.find(guid: service_instance.guid)).to be_nil
          end
        end

        context 'when the space has managed service instances (async deprovision)' do
          let!(:service_instance) { ManagedServiceInstance.make(space: space, name: 'my-async-si') }

          before do
            stub_deprovision(service_instance, accepts_incomplete: true, status: 202, body: { operation: 'deprovision-op' }.to_json)
          end

          it 'enqueues a DeleteServiceInstanceJob as a child' do
            pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)
            job.perform

            child_jobs = PollableJobModel.where(root_job_guid: pollable_job.guid)
            expect(child_jobs.count).to eq(1)
            expect(child_jobs.first.operation).to eq('service_instance.delete')
          end

          it 'does not finish on first cycle' do
            Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)
            job.perform
            expect(job.finished).to be(false)
          end
        end

        context 'phase advancement' do
          it 'advances through all phases for sync resources' do
            AppModel.make(space: space)
            # No managed SIs

            job.perform
            # Phase 1: apps deleted inline → Phase 2: no managed SIs → Phase 3: cleanup → finish
            expect(job.finished).to be(true)
            expect(Space.find(guid: space.guid)).to be_nil
          end
        end

        context 'when a child job fails' do
          it 'raises an error' do
            pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)

            # Create a failed child job
            PollableJobModel.create(
              delayed_job_guid: SecureRandom.uuid,
              state: PollableJobModel::FAILED_STATE,
              operation: 'app.delete',
              resource_guid: 'some-app-guid',
              resource_type: 'app',
              root_job_guid: pollable_job.guid
            )

            expect { job.perform }.to raise_error(CloudController::Errors::ApiError, /Deletion of the following resources failed/)
          end
        end
      end

      describe '#resource_guid' do
        it 'returns the space guid' do
          expect(job.resource_guid).to eq(space.guid)
        end
      end

      describe '#resource_type' do
        it 'returns space' do
          expect(job.resource_type).to eq('space')
        end
      end

      describe '#display_name' do
        it 'returns space.delete' do
          expect(job.display_name).to eq('space.delete')
        end
      end

      describe '#max_attempts' do
        it 'returns 1' do
          expect(job.max_attempts).to eq(1)
        end
      end

      describe '#pollable_job_state' do
        it 'returns PROCESSING' do
          expect(job.pollable_job_state).to eq(PollableJobModel::PROCESSING_STATE)
        end
      end

      describe '#next_execution_in' do
        let!(:pollable_job) { Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job) }

        context 'when sub-jobs have a future run_at' do
          before do
            dj = Delayed::Job.create(guid: 'sub-dj-guid', handler: 'fake', run_at: Time.now + 120)
            PollableJobModel.create(
              delayed_job_guid: dj.guid,
              state: PollableJobModel::POLLING_STATE,
              operation: 'service_bindings.delete',
              resource_guid: 'binding-guid',
              resource_type: 'service_bindings',
              root_job_guid: pollable_job.guid
            )
            job.send(:activate_root_job_context)
          end

          after { job.send(:deactivate_root_job_context) }

          it 'returns time until sub-job run_at plus buffer' do
            result = job.send(:next_execution_in)
            expect(result).to be_within(2).of(125)
          end
        end

        context 'when sub-job has been re-enqueued with a new delayed_job_guid' do
          before do
            # Simulate a sub-job that re-enqueued itself (new delayed_job row, updated guid on pollable job)
            old_dj = Delayed::Job.create(guid: 'old-dj-guid', handler: 'fake', run_at: Time.now - 60)
            new_dj = Delayed::Job.create(guid: 'new-dj-guid', handler: 'fake', run_at: Time.now + 300)
            old_dj.destroy

            PollableJobModel.create(
              delayed_job_guid: new_dj.guid,
              state: PollableJobModel::POLLING_STATE,
              operation: 'service_instance.delete',
              resource_guid: 'si-guid',
              resource_type: 'service_instance',
              root_job_guid: pollable_job.guid
            )
            job.send(:activate_root_job_context)
          end

          after { job.send(:deactivate_root_job_context) }

          it 'reads fresh delayed_job_guid and schedules after the sub-job' do
            result = job.send(:next_execution_in)
            expect(result).to be_within(2).of(305)
          end
        end

        context 'when no active sub-jobs exist' do
          before { job.send(:activate_root_job_context) }

          after { job.send(:deactivate_root_job_context) }

          it 'falls back to base class interval plus buffer' do
            result = job.send(:next_execution_in)
            expected = TestConfig.config_instance.get(:broker_client_default_async_poll_interval_seconds) + 5
            expect(result).to eq(expected)
          end
        end
      end
    end
  end
end
