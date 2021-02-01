require 'spec_helper'
require 'messages/droplet_create_message'

module VCAP::CloudController
  RSpec.describe DropletCreateMessage do
    let(:body) do
      {
        'relationships' => {
          'app' => { 'data' => { 'guid' => 'some-app-guid' } }
        },
        'process_types' => { web: 'web-type' }
      }
    end

    it 'returns the correct DropletCreateMessage' do
      message = DropletCreateMessage.new(body)

      expect(message).to be_a(DropletCreateMessage)
      expect(message.relationships_message.app_guid).to eq('some-app-guid')
      expect(message.process_types).to eq(web: 'web-type')
    end

    it 'converts requested keys to symbols' do
      message = DropletCreateMessage.new(body)
      expect(message.requested?(:relationships)).to be_truthy
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:body) do
          {
            unexpected: 'woah',
            relationships: {
              app: { data: { guid: 'some-app-guid' } },
            }
          }
        end

        it 'is not valid' do
          message = DropletCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end
      end

      describe 'relationships' do
        it 'is not valid when app is missing' do
          message = DropletCreateMessage.new({ relationships: {} })
          expect(message).not_to be_valid
          expect(message.errors_on(:relationships)).to include(a_string_including('must include one or more valid relationships'))
        end

        it 'is not valid when app is not an object' do
          message = DropletCreateMessage.new({ relationships: { app: 'hello' } })
          expect(message).not_to be_valid
          expect(message.errors_on(:relationships)).to include(a_string_including('must be structured like'))
        end

        it 'is not valid when app_guid has an invalid guid' do
          message = DropletCreateMessage.new({ relationships: { app: { data: { guid: 876 } } } })
          expect(message.relationships_message.app_guid).not_to be_nil
          expect(message).not_to be_valid
          expect(message.errors_on(:relationships)).to_not be_empty
        end

        it 'is valid when there is a valid app guid' do
          guid = SecureRandom.uuid
          message = DropletCreateMessage.new({ relationships: { app: { data: { guid: guid } } } })
          expect(message.relationships_message.app_guid).to eq(guid)
          expect(message).to be_valid
        end
      end

      describe 'process_types' do
        it 'is valid when process_type is missing' do
          message = DropletCreateMessage.new({ relationships: { app: { data: { guid: 'app-guid' } } } })
          expect(message).to be_valid
        end

        it 'is not valid when process_types is not an object' do
          message = DropletCreateMessage.new({ relationships: { app: { data: { guid: 'app-guid' } } },
            process_types: 867 })
          expect(message).not_to be_valid
          expect(message.errors_on(:process_types)).to include('must be an object')
        end

        it 'is not valid when process_types has an empty key' do
          message = DropletCreateMessage.new({ relationships: { app: { data: { guid: 'app-guid' } } },
            process_types: { "": 'invalid_ptype' } })
          expect(message.process_types).not_to be_nil
          expect(message).not_to be_valid
          expect(message.errors_on(:process_types)).to include('key must not be empty')
        end

        it 'is not valid when process_types has a non-string value' do
          message = DropletCreateMessage.new({ relationships: { app: { data: { guid: 'app-guid' } } },
            process_types: { web: 867 } })
          expect(message.process_types).not_to be_nil
          expect(message).not_to be_valid
          expect(message.errors_on(:process_types)).to include('value must be a string')
        end
      end
    end
  end
end
