require 'spec_helper'
require 'actions/task_cancel'

module VCAP::CloudController
  describe TaskCancel do
    describe '#cancel' do
      subject(:task_cancel) { described_class.new }

      let(:app) { AppModel.make }
      let(:task) { TaskModel.make(name: 'ursulina', command: 'echo hi', app_guid: app.guid, state: TaskModel::RUNNING_STATE) }
      let(:client) { instance_double(VCAP::CloudController::Diego::NsyncClient) }
      let(:user_guid) { 'user-guid' }
      let(:user_email) { 'user-email' }
      let(:user) { User.new guid: user_guid }

      before do
        locator = CloudController::DependencyLocator.instance
        allow(locator).to receive(:nsync_client).and_return(client)
        allow(client).to receive(:cancel_task).and_return(nil)
      end

      it 'cancels a running task and sets the task state to CANCELING' do
        task_cancel.cancel(task: task, user: user, email: user_email)
        expect(task.state).to eq TaskModel::CANCELING_STATE
      end

      it 'tells diego to cancel the task' do
        task_cancel.cancel(task: task, user: user, email: user_email)
        expect(client).to have_received(:cancel_task).with(task)
      end

      it 'creates a task cancel audit event' do
        task_cancel.cancel(task: task, user: user, email: user_email)

        event = Event.last
        expect(event.type).to eq('audit.app.task.cancel')
        expect(event.metadata['task_guid']).to eq(task.guid)
        expect(event.actee).to eq(app.guid)
      end

      context 'when the state is not cancelable' do
        it 'raises InvalidCancel for FAILED' do
          task.state = TaskModel::FAILED_STATE
          task.save

          expect {
            task_cancel.cancel(task: task, user: user, email: user_email)
          }.to raise_error(TaskCancel::InvalidCancel, "Task state is #{TaskModel::FAILED_STATE} and therefore cannot be canceled")
        end

        it 'raises InvalidCancel for SUCCEEDED' do
          task.state = TaskModel::SUCCEEDED_STATE
          task.save

          expect {
            task_cancel.cancel(task: task, user: user, email: user_email)
          }.to raise_error(TaskCancel::InvalidCancel, "Task state is #{TaskModel::SUCCEEDED_STATE} and therefore cannot be canceled")
        end
      end
    end
  end
end
