require 'lightweight_spec_helper'
require 'messages/service_instance_create_message'

module VCAP::CloudController
  RSpec.describe ServiceInstanceCreateMessage do
    let(:body) do
      {
        type: 'user-provided',
        name: 'my-service-instance',
        tags: %w(foo bar baz),
        relationships: {
          space: {
            data: {
              guid: 'space-guid'
            }
          }
        },
        metadata: {
          labels: {
            potato: 'mashed'
          },
          annotations: {
            cheese: 'bono'
          }
        }
      }
    end

    let(:message) { described_class.new(body) }

    it 'accepts the allowed keys' do
      expect(message).to be_valid
      expect(message.requested?(:type)).to be_truthy
      expect(message.requested?(:name)).to be_truthy
      expect(message.requested?(:relationships)).to be_truthy
      expect(message.requested?(:tags)).to be_truthy
    end

    it 'builds the right message' do
      expect(message.type).to eq('user-provided')
      expect(message.name).to eq('my-service-instance')
      expect(message.space_guid).to eq('space-guid')
      expect(message.metadata[:labels]).to eq({ potato: 'mashed' })
      expect(message.metadata[:annotations]).to eq({ cheese: 'bono' })
      expect(message.tags).to contain_exactly('foo', 'bar', 'baz')
    end

    describe 'validations' do
      it 'allows extra keys' do
        body['bogus'] = 'field'

        expect(message).to be_valid
      end

      describe 'type' do
        it 'accepts the valid types' do
          %w{managed user-provided}.each do |t|
            body[:type] = t
            message = described_class.new(body)
            expect(message).to be_valid
          end
        end

        it 'is invalid when is not set' do
          message = described_class.new({})
          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Type must be one of 'managed', 'user-provided'")
        end

        it 'is invalid when is not one of the valid types' do
          message = described_class.new({ 'type' => 'banana' })
          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Type must be one of 'managed', 'user-provided'")
        end
      end

      describe 'name' do
        it 'must be present' do
          body.delete(:name)

          message = described_class.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:name]).to include("can't be blank")
        end

        it 'must be a string' do
          body[:name] = 12

          message = described_class.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:name]).to include('must be a string')
        end
      end

      describe 'metadata' do
        it 'is invalid when there are bogus metadata fields' do
          body.merge!({ metadata: { choppers: 3 } })
          expect(message).not_to be_valid
        end
      end

      describe 'relationships' do
        it 'is invalid when there is no space relationship' do
          body['relationships'] = { foo: {} }

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Relationships Space can't be blank")
        end
      end

      describe 'tags' do
        it 'must be an array if present' do
          body[:tags] = 42

          message = described_class.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:tags]).to include('must be an array')
        end

        it 'must be contain strings' do
          body[:tags] = ['foo', {}, 4]

          message = described_class.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:tags]).to include('must be a list of strings')
        end
      end
    end
  end
end
