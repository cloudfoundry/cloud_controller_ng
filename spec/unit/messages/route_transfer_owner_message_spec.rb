require 'spec_helper'
require 'messages/process_scale_message'
require 'messages/base_message'

module VCAP::CloudController
  RSpec.describe RouteTransferOwnerMessage do
    context 'when unexpected keys are requested' do
      let(:params) { { guid: 'some-guid', unexpected: 'foo' } }

      it 'is not valid' do
        message = RouteTransferOwnerMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
      end
    end

    context 'when guid is not a string' do
      let(:params) { { guid: 5 } }

      it 'is not valid' do
        message = RouteTransferOwnerMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:guid]).to include('must be a string')
      end
    end

    context 'when guid is not present' do
      let(:params) { { guid: '' } }

      it 'is not valid' do
        message = RouteTransferOwnerMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:guid]).to include("can't be blank")
      end
    end
  end
end
