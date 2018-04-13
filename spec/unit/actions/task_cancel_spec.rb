require 'spec_helper'
require 'actions/task_cancel'

module VCAP::CloudController
  RSpec.describe TaskCancel do
    describe '#cancel' do
      subject(:task_cancel) { described_class.new(config) }

      let(:config) do
        Config.new({
        })
      end

      let(:app) { AppModel.make }
      let(:task) { TaskModel.make(name: 'ursulina', command: 'echo hi', app_guid: app.guid, state: TaskModel::RUNNING_STATE) }
      let(:user_audit_info) { instance_double(VCAP::CloudController::UserAuditInfo).as_null_object }
      let(:bbs_client) { instance_double(VCAP::CloudController::Diego::BbsTaskClient, cancel_task: nil) }

      before do
        locator = CloudController::DependencyLocator.instance
        allow(locator).to receive(:bbs_task_client).and_return(bbs_client)
      end

      it 'cancels a running task and sets the task state to CANCELING' do
        task_cancel.cancel(task: task, user_audit_info: user_audit_info)
        expect(task.state).to eq TaskModel::CANCELING_STATE
      end

      it 'creates a task cancel audit event' do
        task_cancel.cancel(task: task, user_audit_info: user_audit_info)

        event = Event.last
        expect(event.type).to eq('audit.app.task.cancel')
        expect(event.metadata['task_guid']).to eq(task.guid)
        expect(event.actee).to eq(app.guid)
      end

      context 'when talking directly with bbs' do
        it 'tells bbs to cancel the task' do
          task_cancel.cancel(task: task, user_audit_info: user_audit_info)
          expect(bbs_client).to have_received(:cancel_task).with(task.guid)
        end
      end

      context 'when the state is not cancelable' do
        it 'raises InvalidCancel for FAILED' do
          task.state = TaskModel::FAILED_STATE
          task.save

          expect {
            task_cancel.cancel(task: task, user_audit_info: user_audit_info)
          }.to raise_error(TaskCancel::InvalidCancel, "Task state is #{TaskModel::FAILED_STATE} and therefore cannot be canceled")
        end

        it 'raises InvalidCancel for SUCCEEDED' do
          task.state = TaskModel::SUCCEEDED_STATE
          task.save

          expect {
            task_cancel.cancel(task: task, user_audit_info: user_audit_info)
          }.to raise_error(TaskCancel::InvalidCancel, "Task state is #{TaskModel::SUCCEEDED_STATE} and therefore cannot be canceled")
        end
      end
    end
  end
end
