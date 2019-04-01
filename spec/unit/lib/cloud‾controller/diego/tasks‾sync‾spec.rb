require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe TasksSync, job_context: :clock do
      subject { TasksSync.new(config: config) }
      let(:config) { instance_double(Config) }

      let(:bbs_task_client) { instance_double(BbsTaskClient) }
      let(:bbs_tasks) { [] }
      let(:fake_workpool) do
        instance_double(WorkPool, drain: nil, submit: nil, exceptions: [])
      end
      let(:logger) { double(:logger, info: nil, error: nil) }

      before do
        CloudController::DependencyLocator.instance.register(:bbs_task_client, bbs_task_client)
        allow(bbs_task_client).to receive(:fetch_task).and_return(nil)
        allow(bbs_task_client).to receive(:fetch_tasks).and_return(bbs_tasks)
        allow(Steno).to receive(:logger).and_return(logger)
        allow(bbs_task_client).to receive(:bump_freshness)
      end

      describe '#sync' do
        it 'bumps freshness' do
          subject.sync
          expect(bbs_task_client).to have_received(:bump_freshness).once
        end

        context 'when bbs and CC are in sync' do
          let!(:task) { TaskModel.make(:running, created_at: 1.minute.ago) }
          let(:bbs_tasks) do
            [::Diego::Bbs::Models::Task.new(task_guid: task.guid)]
          end

          it 'does nothing to the task' do
            expect {
              subject.sync
            }.to_not change { task.reload.state }
          end
        end

        context 'when a running CC task is missing from BBS' do
          let!(:running_task) { TaskModel.make(:running, created_at: 1.minute.ago) }
          let!(:canceling_task) { TaskModel.make(:canceling, created_at: 1.minute.ago) }
          let(:bbs_tasks) { [] }

          it 'marks the tasks as failed' do
            subject.sync

            expect(bbs_task_client).to have_received(:fetch_task).with(running_task.guid)
            expect(bbs_task_client).to have_received(:fetch_task).with(canceling_task.guid)

            expect(running_task.reload.state).to eq(VCAP::CloudController::TaskModel::FAILED_STATE)
            expect(running_task.reload.failure_reason).to eq(BULKER_TASK_FAILURE)

            expect(canceling_task.reload.state).to eq(VCAP::CloudController::TaskModel::FAILED_STATE)
            expect(canceling_task.reload.failure_reason).to eq(BULKER_TASK_FAILURE)
          end

          it 'creates TASK_STOPPED events' do
            subject.sync

            task1_event = AppUsageEvent.find(task_guid: running_task.guid, state: 'TASK_STOPPED')
            expect(task1_event).not_to be_nil
            expect(task1_event.task_guid).to eq(running_task.guid)
            expect(task1_event.parent_app_guid).to eq(running_task.app.guid)

            task2_event = AppUsageEvent.find(task_guid: canceling_task.guid, state: 'TASK_STOPPED')
            expect(task2_event).not_to be_nil
            expect(task2_event.task_guid).to eq(canceling_task.guid)
            expect(task2_event.parent_app_guid).to eq(canceling_task.app.guid)
          end

          it 'bumps freshness' do
            subject.sync
            expect(bbs_task_client).to have_received(:bump_freshness).once
          end
        end

        context 'when bbs does not know about a pending/succeeded task' do
          let!(:pending_task) { TaskModel.make(:pending, created_at: 1.minute.ago) }
          let!(:succeeded_task) { TaskModel.make(:succeeded, created_at: 1.minute.ago) }
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
              expect { subject.sync }.not_to raise_error
              expect(logger).to have_received(:error).with(
                'error-cancelling-task',
                error: error.class.name,
                error_message: error.message,
                error_backtrace: anything
              )
              expect(bbs_task_client).not_to have_received(:bump_freshness)
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
              expect { subject.sync }.not_to raise_error
              expect(logger).to have_received(:error).with(
                'error-cancelling-task',
                error: error.class.name,
                error_message: error.message,
                error_backtrace: anything
              )
              expect(bbs_task_client).not_to have_received(:bump_freshness)
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
            expect(bbs_task_client).not_to have_received(:bump_freshness)
          end
        end

        context 'when a non-Diego error is raised outside of the workpool' do
          let(:error) { Sequel::Error.new('Generic Database Error') }

          before do
            allow(TaskModel).to receive(:where).and_raise(error)
          end

          it 'does not bump freshness' do
            expect { subject.sync }.to raise_error(error)
            expect(bbs_task_client).not_to have_received(:bump_freshness)
          end

          it 'drains the workpool to prevent thread leakage' do
            allow(subject).to receive(:workpool).and_return(fake_workpool)
            expect { subject.sync }.to raise_error(error)

            expect(subject.send(:workpool)).to have_received(:drain)
          end
        end

        context 'when cancelling tasks on diego fails multiple times' do
          let(:bbs_tasks) do
            [
              ::Diego::Bbs::Models::Task.new(task_guid: 'task-guid-1', state: ::Diego::Bbs::Models::Task::State::Running),
              ::Diego::Bbs::Models::Task.new(task_guid: 'task-guid-2', state: ::Diego::Bbs::Models::Task::State::Running),
            ]
          end

          let(:error) { CloudController::Errors::ApiError.new_from_details('RunnerInvalidRequest', 'invalid thing') }

          before do
            allow(bbs_task_client).to receive(:cancel_task).and_raise(error)
          end

          it 'does not update freshness' do
            expect { subject.sync }.not_to raise_error
            expect(bbs_task_client).not_to have_received(:bump_freshness)
          end

          it 'logs all of the exceptions' do
            expect { subject.sync }.not_to raise_error
            expect(logger).to have_received(:error).with(
              'error-cancelling-task',
              error: error.class.name,
              error_message: error.message,
              error_backtrace: anything
            ).twice
            expect(logger).to have_received(:info).with('run-task-sync')
            expect(logger).to have_received(:info).with('sync-failed')
          end
        end

        context 'correctly syncs in batches' do
          let!(:bbs_tasks) { [] }

          before do
            stub_const('VCAP::CloudController::Diego::TasksSync::BATCH_SIZE', 5)
            (TasksSync::BATCH_SIZE + 1).times do |_|
              task = TaskModel.make(:running, created_at: 1.minute.ago)
              bbs_tasks << ::Diego::Bbs::Models::Task.new(task_guid: task.guid)
            end
          end

          it 'does nothing to the task' do
            allow(bbs_task_client).to receive(:cancel_task)
            subject.sync
            expect(bbs_task_client).not_to have_received(:cancel_task)
          end
        end

        context 'when a new task is created after cc initally fetches tasks from bbs' do
          context 'and the newly started task does not complete before checking to see if it should fail' do
            let!(:cc_task) { TaskModel.make(guid: 'some-task-guid', state: TaskModel::RUNNING_STATE) }
            let(:bbs_task) { ::Diego::Bbs::Models::Task.new(task_guid: 'some-task-guid', state: ::Diego::Bbs::Models::Task::State::Running) }

            before do
              expect(bbs_task_client).to receive(:fetch_task).and_return(bbs_task)
            end

            it 'does not fail the new task' do
              subject.sync

              expect(cc_task.reload.state).to eq(TaskModel::RUNNING_STATE)
            end

            it 'does not create TASK_STOPPED events' do
              subject.sync

              task_event = AppUsageEvent.find(task_guid: cc_task.guid, state: 'TASK_STOPPED')
              expect(task_event).to be_nil
            end

            it 'bumps freshness' do
              subject.sync
              expect(bbs_task_client).to have_received(:bump_freshness).once
            end
          end

          context 'and the newly started task completes before the iteration completes' do
            let!(:cc_task) { TaskModel.make(guid: 'some-task-guid', state: TaskModel::RUNNING_STATE) }
            let(:bbs_tasks) { [] }

            before do
              # HACK: simulate a task completing while the iteration is underway
              expect(bbs_task_client).to receive(:fetch_task) do |task_guid|
                expect(task_guid).to eq('some-task-guid')
                cc_task.update(state: TaskModel::SUCCEEDED_STATE)

                nil
              end
            end

            it 'does not fail the new task' do
              subject.sync

              expect(cc_task.reload.state).to eq(TaskModel::SUCCEEDED_STATE)
            end

            it 'bumps freshness' do
              subject.sync
              expect(bbs_task_client).to have_received(:bump_freshness).once
            end
          end
        end
      end
    end
  end
end
