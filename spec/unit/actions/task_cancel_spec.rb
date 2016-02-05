require 'spec_helper'
require 'actions/task_cancel'

module VCAP::CloudController
  describe TaskCancel do
    describe '#cancel' do
      let(:app) { AppModel.make}
      let(:task_to_cancel) { TaskModel.make(name: 'ursulina', command: 'echo hi', app_guid: app.guid, state: TaskModel::RUNNING_STATE)}
      let(:client) { instance_double(VCAP::CloudController::Diego::NsyncClient) }

      before do
        locator = CloudController::DependencyLocator.instance
        allow(locator).to receive(:nsync_client).and_return(client)
        allow(client).to receive(:cancel_task).and_return(nil)
      end

      it 'cancels a running task and sets the task state to CANCELING' do
        TaskCancel.new.cancel(task_to_cancel)
        expect(task_to_cancel.state).to eq TaskModel::CANCELING_STATE
      end

      it 'tells diego to cancel the task' do
        TaskCancel.new.cancel(task_to_cancel)
        expect(client).to have_received(:cancel_task).with(task_to_cancel)
      end
    end
  end
end
