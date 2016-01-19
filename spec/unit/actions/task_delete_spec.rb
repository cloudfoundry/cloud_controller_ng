require 'spec_helper'
require 'actions/task_delete'

module VCAP::CloudController
  describe TaskDelete do
    describe '#delete' do
      let!(:task1) { TaskModel.make }
      let!(:task2) { TaskModel.make }
      let(:task_dataset) { TaskModel.all }

      it 'deletes the tasks' do
        expect {
          TaskDelete.new.delete(task_dataset)
        }.to change { TaskModel.count }.by(-2)
        expect(task1.exists?).to be_falsey
        expect(task2.exists?).to be_falsey
      end
    end
  end
end
