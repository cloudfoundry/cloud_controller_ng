require 'spec_helper'
require 'messages/space_feature_update_message'

module VCAP::CloudController
  RSpec.describe SpaceFeatureUpdateMessage do
    let(:body) do
      {
        'enabled' => true
      }
    end

    describe 'validations' do
      it 'validates that there are not excess fields' do
        body['bogus'] = 'field'
        message = SpaceFeatureUpdateMessage.new(body)

        expect(message).not_to be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
      end

      describe 'enabled' do
        it 'allows true' do
          body = { enabled: true }
          message = SpaceFeatureUpdateMessage.new(body)

          expect(message).to be_valid
        end

        it 'allows false' do
          body = { enabled: false }
          message = SpaceFeatureUpdateMessage.new(body)

          expect(message).to be_valid
        end

        it 'validates that it is a boolean' do
          body = { enabled: 1 }
          message = SpaceFeatureUpdateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Enabled must be a boolean')
        end

        it 'must be present' do
          body = {}
          message = SpaceFeatureUpdateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Enabled must be a boolean')
        end
      end
    end
  end
end
