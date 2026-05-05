require 'spec_helper'
require 'jobs/v3/delete_app_job'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteAppJob do
      let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'test@example.com') }
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }
      let(:app_model) { AppModel.make(space: space, name: 'my-app') }

      subject(:job) { DeleteAppJob.new(app_model.guid, user_audit_info) }

      it_behaves_like 'delayed job', described_class

      describe '#perform' do
        context 'when the app does not exist' do
          before { app_model.destroy }

          it 'finishes the job' do
            job.perform
            expect(job.finished).to be(true)
          end
        end

        context 'when the app has no service bindings' do
          it 'deletes the app and finishes' do
            job.perform
            expect(job.finished).to be(true)
            expect(AppModel.find(guid: app_model.guid)).to be_nil
          end
        end

        context 'when the app has sync service bindings' do
          let(:service_instance) { ManagedServiceInstance.make(space:) }
          let!(:binding) { ServiceBinding.make(app: app_model, service_instance: service_instance) }

          before do
            stub_unbind(binding, accepts_incomplete: true)
          end

          it 'deletes the app and bindings synchronously' do
            job.perform
            expect(job.finished).to be(true)
            expect(AppModel.find(guid: app_model.guid)).to be_nil
            expect(ServiceBinding.where(app_guid: app_model.guid).count).to eq(0)
          end
        end

        context 'when the app has async service bindings' do
          before do
            allow_any_instance_of(AppDelete).to receive(:delete).and_raise(
              AppDelete::AsyncBindingDeletionsTriggered.new('binding operation in progress')
            )
          end

          it 'stops the app' do
            job.perform
            app_model.reload
            expect(app_model.desired_state).to eq(ProcessModel::STOPPED)
          end

          it 'does not delete the app yet' do
            job.perform
            expect(job.finished).to be(false)
            expect(AppModel.find(guid: app_model.guid)).not_to be_nil
          end

          it 'enqueues a DeleteBindingJob as a child (via BindingsDeleteMixin)' do
            pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)

            # Simulate child job already enqueued by BindingsDeleteMixin with root_job_guid
            PollableJobModel.create(
              delayed_job_guid: SecureRandom.uuid,
              state: PollableJobModel::PROCESSING_STATE,
              operation: 'service_bindings.delete',
              resource_guid: 'some-binding',
              resource_type: 'service_bindings',
              root_job_guid: pollable_job.guid
            )

            job.perform
            # Job is waiting for children
            expect(job.finished).to be(false)
          end
        end

        context 'when child binding jobs are still running' do
          let(:service_instance) { ManagedServiceInstance.make(space:) }
          let!(:binding) { ServiceBinding.make(app: app_model, service_instance: service_instance) }

          it 'waits for children to complete' do
            # Enqueue parent job
            pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)

            # Create a child job in PROCESSING state
            PollableJobModel.create(
              delayed_job_guid: SecureRandom.uuid,
              state: PollableJobModel::PROCESSING_STATE,
              operation: 'service_bindings.delete',
              resource_guid: binding.guid,
              resource_type: 'service_bindings',
              root_job_guid: pollable_job.guid
            )

            job.perform
            expect(job.finished).to be(false)
          end
        end

        context 'when child binding jobs have completed' do
          before do
            # Enqueue parent job
            pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)

            # Create a completed child job
            PollableJobModel.create(
              delayed_job_guid: SecureRandom.uuid,
              state: PollableJobModel::COMPLETE_STATE,
              operation: 'service_bindings.delete',
              resource_guid: 'some-binding-guid',
              resource_type: 'service_bindings',
              root_job_guid: pollable_job.guid
            )
          end

          it 'retries deletion (bindings gone, succeeds)' do
            job.perform
            expect(job.finished).to be(true)
            expect(AppModel.find(guid: app_model.guid)).to be_nil
          end
        end
      end

      describe '#resource_guid' do
        it 'returns the app guid' do
          expect(job.resource_guid).to eq(app_model.guid)
        end
      end

      describe '#resource_type' do
        it 'returns app' do
          expect(job.resource_type).to eq('app')
        end
      end

      describe '#display_name' do
        it 'returns app.delete' do
          expect(job.display_name).to eq('app.delete')
        end
      end

      describe '#max_attempts' do
        it 'returns 1' do
          expect(job.max_attempts).to eq(1)
        end
      end
    end
  end
end
