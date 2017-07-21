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

        it 'creates a task stopped usage event' do
          task_delete.delete(task_dataset)

          event = AppUsageEvent.order(:id).last
          expect(event).not_to be_nil
          expect(event.state).to eq('TASK_STOPPED')
          expect(event.task_guid).to eq(task1.guid)
          expect(event.parent_app_guid).to eq(task1.app.guid)
        end
      end
    end
  end
end
