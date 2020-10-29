require 'spec_helper'
require 'actions/task_update'

module VCAP::CloudController
  RSpec.describe TaskUpdate do
    subject(:task_update) { TaskUpdate.new }

    describe '#update' do
      let(:body) do
        {
          metadata: {
            labels: {
              freaky: 'wednesday',
            },
            annotations: {
              tokyo: 'grapes'
            },
          },
        }
      end
      let(:task) { TaskModel.make }
      let(:message) { TaskUpdateMessage.new(body) }

      it 'updates the task metadata' do
        expect(message).to be_valid
        task_update.update(task, message)

        task.reload
        expect(task).to have_labels({ key: 'freaky', value: 'wednesday' })
        expect(task).to have_annotations({ key: 'tokyo', value: 'grapes' })
      end
    end
  end
end
