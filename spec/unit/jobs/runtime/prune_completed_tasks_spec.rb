require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe PruneCompletedTasks, job_context: :worker do
      let(:cutoff_age_in_days) { 30 }
      let(:logger) { instance_double(Steno::Logger, info: nil) }

      subject(:job) do
        PruneCompletedTasks.new(cutoff_age_in_days)
      end

      before do
        allow(Steno).to receive(:logger).and_return(logger)
      end

      it { is_expected.to be_a_valid_job }

      it 'can be enqueued' do
        expect(job).to respond_to(:perform)
      end

      describe '#perform' do
        context 'when tasks are older than the cutoff age' do
          let(:time_after_expiration) { Time.now.utc + (cutoff_age_in_days + 1).days }

          it 'deletes succeeded and failed tasks' do
            failed_task    = TaskModel.make(state: TaskModel::FAILED_STATE)
            succeeded_task = TaskModel.make(state: TaskModel::SUCCEEDED_STATE)

            Timecop.travel(time_after_expiration) do
              expect(failed_task).to exist
              expect(succeeded_task).to exist
              job.perform
              expect(failed_task).not_to exist
              expect(succeeded_task).not_to exist
            end
          end

          it 'deletes tasks with labels' do
            labeled_task = TaskModel.make(state: TaskModel::FAILED_STATE)

            TaskLabelModel.make(key_name: 'cool', value: 'stuff', task: labeled_task)

            Timecop.travel(time_after_expiration) do
              expect(labeled_task).to exist
              job.perform
              expect(labeled_task).not_to exist
            end
          end

          it 'does not delete pending or running tasks' do
            running_task = TaskModel.make(state: TaskModel::RUNNING_STATE)
            pending_task = TaskModel.make(state: TaskModel::PENDING_STATE)

            Timecop.travel(time_after_expiration) do
              expect(running_task).to exist
              expect(pending_task).to exist
              job.perform
              expect(running_task).to exist
              expect(pending_task).to exist
            end
          end

          describe 'logging' do
            it 'logs the number of deleted tasks' do
              TaskModel.make(state: TaskModel::FAILED_STATE)
              TaskModel.make(state: TaskModel::FAILED_STATE)
              TaskModel.make(state: TaskModel::SUCCEEDED_STATE)

              Timecop.travel(time_after_expiration) do
                expect(logger).to receive(:info).with('Cleaned up 3 TaskModel rows')
                job.perform
              end
            end

            it 'logs the number of deleted labels' do
              labeled_task = TaskModel.make(state: TaskModel::FAILED_STATE)
              TaskLabelModel.make(key_name: 'cool', value: 'stuff', task: labeled_task)

              Timecop.travel(time_after_expiration) do
                expect(logger).to receive(:info).with('Cleaned up 1 TaskLabelModel rows')
                job.perform
              end
            end
          end
        end

        context 'when tasks are younger than the cutoff age' do
          let(:time_before_expiration) { Time.now.utc + (cutoff_age_in_days - 1).days }

          it 'does not delete succeeded, failed, pending, or running tasks' do
            running_task   = TaskModel.make(state: TaskModel::RUNNING_STATE)
            pending_task   = TaskModel.make(state: TaskModel::PENDING_STATE)
            failed_task    = TaskModel.make(state: TaskModel::FAILED_STATE)
            succeeded_task = TaskModel.make(state: TaskModel::SUCCEEDED_STATE)

            Timecop.travel(time_before_expiration) do
              expect(running_task).to exist
              expect(pending_task).to exist
              expect(failed_task).to exist
              expect(succeeded_task).to exist

              job.perform

              expect(failed_task).to exist
              expect(succeeded_task).to exist
              expect(running_task).to exist
              expect(pending_task).to exist
            end
          end
        end
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:prune_completed_tasks)
      end
    end
  end
end
