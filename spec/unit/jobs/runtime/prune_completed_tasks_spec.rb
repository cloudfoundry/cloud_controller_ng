require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe PruneCompletedTasks do
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
              expect(failed_task.exists?).to be_truthy
              expect(succeeded_task.exists?).to be_truthy
              job.perform
              expect(failed_task.exists?).to be_falsey
              expect(succeeded_task.exists?).to be_falsey
            end
          end

          it 'does not delete pending or running tasks' do
            running_task = TaskModel.make(state: TaskModel::RUNNING_STATE)
            pending_task = TaskModel.make(state: TaskModel::PENDING_STATE)

            Timecop.travel(time_after_expiration) do
              expect(running_task.exists?).to be_truthy
              expect(pending_task.exists?).to be_truthy
              job.perform
              expect(running_task.exists?).to be_truthy
              expect(pending_task.exists?).to be_truthy
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
              expect(running_task.exists?).to be_truthy
              expect(pending_task.exists?).to be_truthy
              expect(failed_task.exists?).to be_truthy
              expect(succeeded_task.exists?).to be_truthy

              job.perform

              expect(failed_task.exists?).to be_truthy
              expect(succeeded_task.exists?).to be_truthy
              expect(running_task.exists?).to be_truthy
              expect(pending_task.exists?).to be_truthy
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
