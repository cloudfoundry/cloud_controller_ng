require 'spec_helper'
require 'messages/process_scale_message'
require 'messages/base_message'

module VCAP::CloudController
  RSpec.describe RouteTransferOwnerMessage do
    describe 'validations' do
      context 'when it contains the right content' do
        let(:symbolized_body) do
          {
            data: { guid: 'some-guid' }
          }
        end

        it 'it is valid' do
          message = RouteTransferOwnerMessage.new(symbolized_body)

          expect(message).to be_valid
          expect(message.errors.count).to eq(0)
        end
      end

      context 'when there is no data in the object' do
        let(:symbolized_body) do
          {}
        end

        it 'returns an error' do
          message = RouteTransferOwnerMessage.new(symbolized_body)

          expect(message).to_not be_valid
          expect(message.errors[:data]).to include("can't be blank")
        end
      end

      context 'when there is no guid in the data' do
        let(:symbolized_body) do
          {
            data: {}
          }
        end

        it 'returns an error' do
          message = RouteTransferOwnerMessage.new(symbolized_body)

          expect(message).to_not be_valid
          expect(message.errors[:data]).to include("can't be blank")
        end
      end

      context 'when data is nil' do
        let(:symbolized_body) do
          {
            data: nil
          }
        end

        it 'does not error and returns the correct message' do
          message = RouteTransferOwnerMessage.new(symbolized_body)

          expect(message).not_to be_valid
          expect(message.errors[:data]).to include("can't be blank")
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) { { data: { guid: 'some-guid' }, unexpected: 'foo' } }

        it 'is not valid' do
          message = RouteTransferOwnerMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end

        context 'when there are unexpected keys inside data hash' do
          let(:symbolized_body) {
            {
              data: { blah: 'awesome-guid' },
            }
          }

          it 'is not valid' do
            message = RouteTransferOwnerMessage.new(symbolized_body)

            expect(message).to_not be_valid
            expect(message.errors[:data]).to include("can only accept key 'guid'")
          end
        end
      end

      context 'when guid is not a string' do
        let(:symbolized_body) do
          {
            data: { guid: 32.77 }
          }
        end

        it 'is not valid' do
          message = RouteTransferOwnerMessage.new(symbolized_body)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors[:data]).to include('32.77 must be a string')
        end
      end

      context 'when guid is not present' do
        let(:symbolized_body) do
          {
            data: { guid: '' }
          }
        end

        it 'is not valid' do
          message = RouteTransferOwnerMessage.new(symbolized_body)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors[:data]).to include("guid can't be blank")
        end
      end
    end
  end
end
