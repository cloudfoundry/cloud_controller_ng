require 'spec_helper'
require 'messages/task_create_message'

module VCAP::CloudController
  describe TaskCreateMessage do
    describe '.create' do
      let(:body) do
        {
          'name': 'mytask',
          'command': 'rake db:migrate && true',
        }
      end

      it 'returns the correct TaskCreateMessage' do
        message = TaskCreateMessage.create(body)

        expect(message).to be_a(TaskCreateMessage)
        expect(message.name).to eq('mytask')
        expect(message.command).to eq('rake db:migrate && true')
      end

      it 'validates that there are not excess fields' do
        body.merge! 'bogus': 'field'
        message = TaskCreateMessage.create(body)

        expect(message).to_not be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
      end
    end
  end
end
