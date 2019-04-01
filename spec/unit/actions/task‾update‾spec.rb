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
        expect(task.labels.map { |label| { key: label.key_name, value: label.value } }).to match_array([{ key: 'freaky', value: 'wednesday' }])
        expect(task.annotations.map { |a| { key: a.key, value: a.value } }).
          to match_array([{ key: 'tokyo', value: 'grapes' }])
      end
    end
  end
end
