require 'spec_helper'
require 'messages/route_mappings_update_message'

module VCAP::CloudController
  RSpec.describe RouteMappingsUpdateMessage do
    let(:weight) { 3 }
    let(:body) do
      {
        'weight' => weight
      }
    end

    it 'returns the correct RouteMappingsUpdateMessage' do
      message = RouteMappingsUpdateMessage.new(body)

      expect(message).to be_a(RouteMappingsUpdateMessage)
      expect(message.weight).to eq(3)
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:body) do
          {
            unexpected:    'woah',
            weight:      '123',
          }
        end

        it 'is not valid' do
          message = RouteMappingsUpdateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end
      end

      describe 'weight' do
        let(:message) { RouteMappingsUpdateMessage.new(body) }
        context 'when weight is less than 1' do
          let(:weight) { 0 }

          it 'is invalid' do
            expect(message).to be_invalid
            expect(message.errors[:weight]).to include('0 must be an integer between 1 and 128')
          end
        end

        context 'when weight is greater than 128' do
          let(:weight) { 129 }

          it 'is invalid' do
            expect(message).to be_invalid
            expect(message.errors[:weight]).to include('129 must be an integer between 1 and 128')
          end
        end

        context 'when weight is between 1 and 128' do
          let(:weight) { 128 }

          it 'is valid' do
            expect(message).to be_valid
          end
        end
      end
    end
  end
end
