require 'spec_helper'
require 'actions/task_delete'

module VCAP::CloudController
  RSpec.describe TaskDelete do
    describe '#delete' do
      subject(:task_delete) { described_class.new(user_audit_info) }

      let!(:task1) { TaskModel.make(state: TaskModel::SUCCEEDED_STATE) }
      let!(:task2) { TaskModel.make(state: TaskModel::SUCCEEDED_STATE) }
      let(:task_dataset) { TaskModel.all }
      let(:user_audit_info) { instance_double(VCAP::CloudController::UserAuditInfo).as_null_object }
      let(:nsync_client) { instance_double(VCAP::CloudController::Diego::NsyncClient, cancel_task: nil) }
      let(:bbs_task_client) { instance_double(VCAP::CloudController::Diego::BbsTaskClient, cancel_task: nil) }

      it 'deletes the tasks' do
        expect {
          task_delete.delete(task_dataset)
        }.to change { TaskModel.count }.by(-2)
        expect(task1.exists?).to be_falsey
        expect(task2.exists?).to be_falsey
      end

      context 'when the task is running' do
        let!(:task1) { TaskModel.make(state: TaskModel::RUNNING_STATE) }

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:nsync_client).and_return(nsync_client)
          allow(CloudController::DependencyLocator.instance).to receive(:bbs_task_client).and_return(bbs_task_client)
        end

        context 'when talking with nsync' do
          before { TestConfig.override(diego: { temporary_local_tasks: false }) }

          it 'sends a cancel request to nsync_client' do
            task_delete.delete(task_dataset)
            expect(nsync_client).to have_received(:cancel_task).with(task1)
          end
        end

        context 'when talking with bbs client directly' do
          before { TestConfig.override(diego: { temporary_local_tasks: true }) }

          it 'sends a cancel request to bbs_task_client' do
            task_delete.delete(task_dataset)
            expect(bbs_task_client).to have_received(:cancel_task).with(task1.guid)
          end
        end

        it 'creates a task cancel audit event' do
          task_delete.delete(task_dataset)

          event = Event.order(:id).last
          expect(event).not_to be_nil
          expect(event.type).to eq('audit.app.task.cancel')
          expect(event.metadata['task_guid']).to eq(task1.guid)
          expect(event.actee).to eq(task1.app.guid)
        end

        context 'when deleting multiple tasks' do
          context 'when some tasks are in terminal states' do
            let!(:task1) { TaskModel.make(state: TaskModel::RUNNING_STATE) }
            let!(:task2) { TaskModel.make(state: TaskModel::SUCCEEDED_STATE) }
            let!(:task3) { TaskModel.make(state: TaskModel::FAILED_STATE) }

            it 'creates a TASK_STOPPED usage events non-terminal tasks' do
              task_delete.delete(task_dataset)

              task1_event = AppUsageEvent.find(task_guid: task1.guid, state: 'TASK_STOPPED')
              expect(task1_event).not_to be_nil
              expect(task1_event.task_guid).to eq(task1.guid)
              expect(task1_event.parent_app_guid).to eq(task1.app.guid)

              task2_event = AppUsageEvent.find(task_guid: task2.guid, state: 'TASK_STOPPED')
              expect(task2_event).to be_nil

              task3_event = AppUsageEvent.find(task_guid: task3.guid, state: 'TASK_STOPPED')
              expect(task3_event).to be_nil
            end
          end

          context 'when both tasks are not in terminal states' do
            let!(:task1) { TaskModel.make(state: TaskModel::RUNNING_STATE) }
            let!(:task2) { TaskModel.make(state: TaskModel::PENDING_STATE) }

            it 'creates a TASK_STOPPED usage events for the deleted tasks' do
              task_delete.delete(task_dataset)

              task1_event = AppUsageEvent.find(task_guid: task1.guid, state: 'TASK_STOPPED')
              expect(task1_event).not_to be_nil
              expect(task1_event.task_guid).to eq(task1.guid)
              expect(task1_event.parent_app_guid).to eq(task1.app.guid)

              task2_event = AppUsageEvent.find(task_guid: task2.guid, state: 'TASK_STOPPED')
              expect(task2_event).not_to be_nil
              expect(task2_event.task_guid).to eq(task2.guid)
              expect(task2_event.parent_app_guid).to eq(task2.app.guid)
            end
          end
        end
      end
    end
  end
end
