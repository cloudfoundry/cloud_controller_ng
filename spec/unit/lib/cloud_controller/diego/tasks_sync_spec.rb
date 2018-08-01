require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe TasksSync do
      subject { TasksSync.new(config) }
      let(:config) { double(:config) }

      let(:bbs_task_client) { instance_double(BbsTaskClient) }
      let(:bbs_tasks) { [] }

      before do
        CloudController::DependencyLocator.instance.register(:bbs_task_client, bbs_task_client)
        allow(bbs_task_client).to receive(:fetch_tasks).and_return(bbs_tasks)
        allow(bbs_task_client).to receive(:bump_freshness)
      end

      describe '#sync' do
        it 'bumps freshness' do
          subject.sync
          expect(bbs_task_client).to have_received(:bump_freshness).once
        end

        context 'when bbs and CC are in sync' do
          let!(:task) { TaskModel.make(:running) }
          let(:bbs_tasks) do
            [::Diego::Bbs::Models::Task.new(task_guid: task.guid)]
          end

          it 'does nothing to the task' do
            expect {
              subject.sync
            }.to_not change { task.reload.state }
          end
        end

        context 'when bbs does not know about a running/canceling task' do
          let!(:running_task) { TaskModel.make(:running) }
          let!(:canceling_task) { TaskModel.make(:canceling) }
          let(:bbs_tasks) { [] }

          it 'marks the task as failed' do
            subject.sync

            expect(running_task.reload.state).to eq(VCAP::CloudController::TaskModel::FAILED_STATE)
            expect(running_task.reload.failure_reason).to eq(BULKER_TASK_FAILURE)

            expect(canceling_task.reload.state).to eq(VCAP::CloudController::TaskModel::FAILED_STATE)
            expect(canceling_task.reload.failure_reason).to eq(BULKER_TASK_FAILURE)
          end

          it 'bumps freshness' do
            subject.sync
            expect(bbs_task_client).to have_received(:bump_freshness).once
          end
        end

        context 'when bbs does not know about a pending/succeeded task' do
          let!(:pending_task) { TaskModel.make(:pending) }
          let!(:succeeded_task) { TaskModel.make(:succeeded) }
          let(:bbs_tasks) { [] }

          it 'does nothing to the task' do
            expect { subject.sync }.to_not change {
              [pending_task.reload.state, succeeded_task.reload.state]
            }
          end

          it 'bumps freshness' do
            subject.sync
            expect(bbs_task_client).to have_received(:bump_freshness).once
          end
        end

        context 'when bbs knows about a running task that CC does not' do
          let(:bbs_tasks) do
            [::Diego::Bbs::Models::Task.new(task_guid: 'task-guid-1', state: ::Diego::Bbs::Models::Task::State::Running)]
          end

          before do
            allow(bbs_task_client).to receive(:cancel_task)
          end

          it 'attempts to cancel the task' do
            subject.sync
            expect(bbs_task_client).to have_received(:cancel_task).with('task-guid-1')
          end

          it 'bumps freshness' do
            subject.sync
            expect(bbs_task_client).to have_received(:bump_freshness).once
          end

          context 'when canceling the task fails' do
            # bbs_task_client will raise ApiErrors as of right now, we should think about factoring that out so that
            # the background job doesn't have to deal with API concerns
            let(:error) { CloudController::Errors::ApiError.new }

            before do
              allow(bbs_task_client).to receive(:cancel_task).and_raise(error)
            end

            it 'does not bump freshness' do
              expect { subject.sync }.to raise_error(TasksSync::BBSFetchError, error.message)
              expect(bbs_task_client).not_to receive(:bump_freshness)
            end
          end
        end

        context 'when bbs knows about a running task that CC wants to cancel' do
          let!(:canceling_task) { TaskModel.make(:canceling) }
          let(:bbs_tasks) do
            [::Diego::Bbs::Models::Task.new(task_guid: canceling_task.guid)]
          end

          before do
            allow(bbs_task_client).to receive(:cancel_task)
          end

          it 'attempts to cancel the task' do
            subject.sync
            expect(bbs_task_client).to have_received(:cancel_task).with(canceling_task.guid)
          end

          it 'bumps freshness' do
            subject.sync
            expect(bbs_task_client).to have_received(:bump_freshness).once
          end

          context 'when canceling the task fails' do
            # bbs_task_client will raise ApiErrors as of right now, we should think about factoring that out so that
            # the background job doesn't have to deal with API concerns
            let(:error) { CloudController::Errors::ApiError.new }

            before do
              allow(bbs_task_client).to receive(:cancel_task).and_raise(error)
            end

            it 'does not bump freshness' do
              expect { subject.sync }.to raise_error(TasksSync::BBSFetchError, error.message)
              expect(bbs_task_client).not_to receive(:bump_freshness)
            end
          end
        end

        context 'when fetching from diego fails' do
          # bbs_task_client will raise ApiErrors as of right now, we should think about factoring that out so that
          # the background job doesn't have to deal with API concerns
          let(:error) { CloudController::Errors::ApiError.new }

          before do
            allow(bbs_task_client).to receive(:fetch_tasks).and_raise(error)
          end

          it 'does not bump freshness' do
            expect { subject.sync }.to raise_error(TasksSync::BBSFetchError, error.message)
            expect(bbs_task_client).not_to receive(:bump_freshness)
          end
        end
      end
    end
  end
end
