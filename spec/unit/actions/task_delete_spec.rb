require 'spec_helper'
require 'actions/task_delete'

module VCAP::CloudController
  describe TaskDelete do
    describe '#delete' do
      subject(:task_delete) { described_class.new('user-guid', 'user@example.com') }

      let!(:task1) { TaskModel.make(state: TaskModel::SUCCEEDED_STATE) }
      let!(:task2) { TaskModel.make(state: TaskModel::SUCCEEDED_STATE) }
      let(:task_dataset) { TaskModel.all }

      it 'deletes the tasks' do
        expect {
          task_delete.delete(task_dataset)
        }.to change { TaskModel.count }.by(-2)
        expect(task1.exists?).to be_falsey
        expect(task2.exists?).to be_falsey
      end

      context 'when the task is running' do
        let!(:task1) { TaskModel.make(state: TaskModel::RUNNING_STATE) }
        let(:client) { instance_double(VCAP::CloudController::Diego::NsyncClient) }

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:nsync_client).and_return(client)
          allow(client).to receive(:cancel_task).and_return(nil)
        end

        it 'sends a cancel request' do
          task_delete.delete(task_dataset)
          expect(client).to have_received(:cancel_task).with(task1)
        end

        it 'creates a task cancel audit event' do
          task_delete.delete(task_dataset)

          event = Event.order(:id).last
          expect(event.type).to eq('audit.app.task.cancel')
          expect(event.metadata['task_guid']).to eq(task1.guid)
          expect(event.actee).to eq(task1.app.guid)
          expect(event.actor).to eq('user-guid')
          expect(event.actor_name).to eq('user@example.com')
        end
      end
    end
  end
end
