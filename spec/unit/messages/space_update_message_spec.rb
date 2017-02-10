require 'spec_helper'
require 'messages/space_update_message'

module VCAP::CloudController
  RSpec.describe SpaceUpdateMessage do
    describe '.create_from_http_request' do
      let(:body) {
        {
          'data' => {
            'guid' => 'foobar'
          }
        }
      }

      it 'returns the correct SpaceUpdateMessage' do
        message = SpaceUpdateMessage.create_from_http_request(body)

        expect(message).to be_a(SpaceUpdateMessage)
        expect(message.data).to be_a(Hash)
        expect(message.data['guid']).to eq('foobar')
      end

      it 'converts requested keys to symbols' do
        message = SpaceUpdateMessage.create_from_http_request(body)

        expect(message.requested?(:data)).to be_truthy
      end
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'foo' } }

        it 'is valid because data is assumed to be nil' do
          message = SpaceUpdateMessage.new(params)

          expect(message).to be_valid
        end
      end

      context 'when data is nil' do
        let(:params) { { data: nil } }

        it 'is valid' do
          message = SpaceUpdateMessage.new(params)

          expect(message).to be_valid
        end
      end

      context 'when data is not a hash' do
        let(:params) { { data: 'foo' } }

        it 'is not valid' do
          message = SpaceUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:data]).to include('data must be a hash')
        end
      end

      context 'when data is a hash with a guid only' do
        let(:params) { { data: { 'guid' => 'guid-1' } } }

        it 'is valid' do
          message = SpaceUpdateMessage.new(params)

          expect(message).to be_valid
          expect(message.data['guid']).to eq('guid-1')
        end
      end

      context 'when data is a hash with no guid' do
        let(:params) { { data: { 'foo' => 3 } } }

        it 'is not valid' do
          message = SpaceUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:data]).to include('Invalid keys: foo')
        end
      end
    end
  end
end
