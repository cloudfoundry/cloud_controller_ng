require 'spec_helper'
require 'messages/droplet_copy_message'

module VCAP::CloudController
  RSpec.describe DropletCopyMessage do
    let(:body) do
      {
        'relationships' => {
          'app' => { 'guid' => 'some-app-guid' }
        }
      }
    end

    it 'returns the correct DropletCopyMessage' do
      message = DropletCopyMessage.create_from_http_request(body)

      expect(message).to be_a(DropletCopyMessage)
      expect(message.app_guid).to eq('some-app-guid')
    end

    it 'converts requested keys to symbols' do
      message = DropletCopyMessage.create_from_http_request(body)
      expect(message.requested?(:relationships)).to be_truthy
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:body) do
          {
            unexpected: 'woah',
            relationships: {
              app: { guid: 'some-app-guid' },
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
          expect(message.errors_on(:app)).to include('must be a hash')
        end

        it 'is not valid when app is not a hash' do
          message = DropletCopyMessage.new({ relationships: { app: 'hello' } })
          expect(message).not_to be_valid
          expect(message.errors_on(:app)).to include('must be a hash')
        end

        it 'is not valid when app_guid has an invalid guid' do
          message = DropletCopyMessage.new({ relationships: { app: { guid: 876 } } })
          expect(message).not_to be_valid
          expect(message.errors_on(:app_guid)).to_not be_empty
        end
      end
    end
  end
end
