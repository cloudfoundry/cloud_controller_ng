require 'spec_helper'
require 'messages/process_scale_message'

module VCAP::CloudController
  describe ProcessScaleMessage do
    context 'when instances is not an number' do
      let(:params) { { instances: 'silly string thing' } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include('is not a number')
      end
    end

    context 'when instances is not an integer' do
      let(:params) { { instances: 3.5 } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include('must be an integer')
      end
    end
  end
end
