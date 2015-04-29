require 'spec_helper'
require 'messages/process_scale_message'

module VCAP::CloudController
  describe ProcessScaleMessage do
    context 'when unexpected keys are requested' do
      let(:params) { { instances: 3, unexpected: 'foo' } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
      end
    end

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

    describe '.create_from_http_request' do
      let(:body) { { 'instances' => 3 } }

      it 'returns the correct ProcessScaleMessage' do
        message = ProcessScaleMessage.create_from_http_request(body)

        expect(message).to be_a(ProcessScaleMessage)
        expect(message.instances).to eq(3)
      end

      it 'converts requested keys to symbols' do
        message = ProcessScaleMessage.create_from_http_request(body)

        expect(message.requested?(:instances)).to be_truthy
      end
    end
  end
end
