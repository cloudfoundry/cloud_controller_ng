require 'spec_helper'
require 'messages/droplet_copy_message'

module VCAP::CloudController
  RSpec.describe DropletCopyMessage do
    let(:body) do
      {
        'relationships' => {
          'app' => { 'data' => { 'guid' => 'some-app-guid' } }
        }
      }
    end

    it 'returns the correct DropletCopyMessage' do
      message = DropletCopyMessage.new(body)

      expect(message).to be_a(DropletCopyMessage)
      expect(message.app_guid).to eq('some-app-guid')
    end

    it 'converts requested keys to symbols' do
      message = DropletCopyMessage.new(body)
      expect(message.requested?(:relationships)).to be_truthy
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:body) do
          {
            unexpected:    'woah',
            relationships: {
              app: { data: { guid: 'some-app-guid' } },
            }
          }
        end

        it 'is not valid' do
          message = DropletCopyMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end
      end

      describe 'app' do
        it 'is not valid when app is missing' do
          message = DropletCopyMessage.new({ relationships: {} })
          expect(message).not_to be_valid
          expect(message.errors_on(:app)).to include('must be an object')
        end

        it 'is not valid when app is not an object' do
          message = DropletCopyMessage.new({ relationships: { app: 'hello' } })
          expect(message).not_to be_valid
          expect(message.errors_on(:app)).to include('must be an object')
        end

        it 'is not valid when app_guid has an invalid guid' do
          message = DropletCopyMessage.new({ relationships: { app: { data: { guid: 876 } } } })
          expect(message.app_guid).not_to be_nil
          expect(message).not_to be_valid
          expect(message.errors_on(:app_guid)).to_not be_empty
        end

        it 'is valid when there is a valid app guid' do
          guid    = SecureRandom.uuid
          message = DropletCopyMessage.new({ relationships: { app: { data: { guid: guid } } } })
          expect(message.app_guid).to eq(guid)
          expect(message).to be_valid
        end
      end
    end
  end
end
