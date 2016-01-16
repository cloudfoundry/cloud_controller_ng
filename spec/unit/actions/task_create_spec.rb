require 'spec_helper'
require 'actions/task_create'

module VCAP::CloudController
  describe TaskCreate do
    describe '#create' do
      let(:app) { AppModel.make }
      let(:droplet) { DropletModel.make(app_guid: app.guid, state: DropletModel::STAGED_STATE) }
      let(:command) { 'bundle exec rake panda' }
      let(:name) { 'my_task_name' }
      let(:message) { TaskCreateMessage.new name: name, command: command }

      before do
        app.droplet = droplet
        app.save
      end

      let(:task) { TaskCreate.new.create(app, message) }

      it 'creates and returns a task using the given app and its droplet' do
        expect(task.app).to eq(app)
        expect(task.droplet).to eq(droplet)
        expect(task.command).to eq(command)
        expect(task.name).to eq(name)
      end

      it "sets the task state to 'RUNNING'" do
        expect(task.state).to eq(TaskModel::RUNNING_STATE)
      end

      context 'when the task is invalid' do
        before do
          allow_any_instance_of(TaskModel).to receive(:save).and_raise(Sequel::ValidationFailed.new('booooooo'))
        end

        it 'raises an InvalidTask error' do
          expect {
            TaskCreate.new.create(app, message)
          }.to raise_error(TaskCreate::InvalidTask, 'booooooo')
        end
      end
    end
  end
end
