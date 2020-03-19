require 'lightweight_spec_helper'
require 'messages/service_instance_create_message'

module VCAP::CloudController
  RSpec.describe ServiceInstanceCreateMessage do
    let(:body) do
      {
        "type": 'managed',
        "relationships": {
          "space": {
            "data": {
              "guid": 'space-guid'
            }
          }
        },
        "metadata": {
          "labels": {
            "potato": 'mashed'
          },
          "annotations": {
            "cheese": 'bono'
          }
        }
      }
    end

    let(:message) {
      ServiceInstanceCreateMessage.new(body)
    }

    it 'accepts the allowed keys' do
      expect(message).to be_valid
      expect(message.requested?(:type)).to be_truthy
      expect(message.requested?(:relationships)).to be_truthy
      expect(message.requested?(:metadata)).to be_truthy
    end

    it 'builds the right message' do
      expect(message.type).to eq('managed')
      expect(message.space_guid).to eq('space-guid')
      expect(message.metadata[:labels]).to eq({ potato: 'mashed' })
      expect(message.metadata[:annotations]).to eq({ cheese: 'bono' })
    end

    describe 'validations' do
      it 'is invalid when there are unknown keys' do
        body['bogus'] = 'field'

        expect(message).to_not be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
      end

      describe 'metadata' do
        it 'is invalid when there are bogus metadata fields' do
          body.merge!({ "metadata": { "choppers": 3 } })
          expect(message).not_to be_valid
        end
      end

      describe 'relationships' do
        it 'is invalid when there is no space relationship' do
          body['relationships'] = { 'foo': {} }

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Relationships Space can't be blank")
        end

        it 'is invalid when there are unknown relationships' do
          body['relationships'] = { 'service-offering' => { 'data' => { 'guid' => 'offering-guid' } } }

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Relationships Unknown field(s): 'service-offering'")
        end
      end

      describe 'type' do
        it 'accepts the valid types' do
          %w{managed user-provided}.each do |t|
            body['type'] = t
            message = ServiceInstanceCreateMessage.new(body)
            expect(message).to be_valid
          end
        end

        it 'is invalid when is not set' do
          message = ServiceInstanceCreateMessage.new({})
          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Type must be one of 'managed', 'user-provided'")
        end

        it 'is invalid when is not one of the valid types' do
          message = ServiceInstanceCreateMessage.new({ 'type' => 'banana' })
          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Type must be one of 'managed', 'user-provided'")
        end
      end
    end
  end
end
