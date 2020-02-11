require 'spec_helper'
require 'messages/to_many_relationship_message'

module VCAP::CloudController
  RSpec.describe ToManyRelationshipMessage do
    describe 'validations' do
      context 'when there are no guids in the data' do
        let(:params) do
          {
            data: []
          }
        end

        it 'returns an error' do
          message = ToManyRelationshipMessage.new(params)

          expect(message).to_not be_valid
          expect(message.errors[:data]).to include("can't be blank")
        end
      end

      context 'when data is not an array' do
        let(:params) do
          {
            data: 'boo'
          }
        end

        it 'returns an error' do
          message = ToManyRelationshipMessage.new(params)

          expect(message).to_not be_valid
          expect(message.errors[:data]).to include('must be an array')
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) {
          {
            unexpected: 'an-unexpected-value',
          }
        }

        it 'is not valid' do
          message = ToManyRelationshipMessage.new(params)

          expect(message).to_not be_valid
          expect(message.errors[:base]).to contain_exactly("Unknown field(s): 'unexpected'")
        end
      end

      context 'when unexpected values are requested' do
        it 'is NOT valid and includes an error specifying the expected input format' do
          message = ToManyRelationshipMessage.new({ data: [{ guid: 32.77 }] })

          expect(message).to be_invalid
          expect(message.errors.full_messages).to contain_exactly('Invalid data type: Data[0] guid should be a string.')
        end
      end
    end

    context 'with guids provided as strings' do
      it 'is valid ' do
        message = ToManyRelationshipMessage.new({ data: [{ guid: 'some-guid' }] })

        expect(message).to be_valid
      end
    end
  end
end
