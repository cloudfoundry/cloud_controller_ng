require 'spec_helper'
require 'actions/stack_update'

module VCAP::CloudController
  RSpec.describe StackUpdate do
    subject(:stack_update) { StackUpdate.new }

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
      let(:stack) { Stack.make }
      let(:message) { StackUpdateMessage.new(body) }

      it 'updates the stack metadata' do
        expect(message).to be_valid
        stack_update.update(stack, message)

        stack.reload
        expect(stack).to have_labels({ key: 'freaky', value: 'wednesday' })
        expect(stack).to have_annotations({ key: 'tokyo', value: 'grapes' })
      end
    end
  end
end
