require 'spec_helper'
require 'messages/service_instance_update_managed_message'

module VCAP::CloudController
  RSpec.describe ServiceInstanceUpdateManagedMessage do
    let(:body) do
      {
        name: 'my-service-instance',
        parameters: { foo: 'bar' },
        tags: %w(foo bar baz),
        maintenance_info: {
          version: '1.3.3'
        },
        relationships: {
          service_plan: {
            data: { guid: 'service-plan-guid' }
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
      expect(message.requested?(:name)).to be_truthy
      expect(message.requested?(:relationships)).to be_truthy
      expect(message.requested?(:tags)).to be_truthy
      expect(message.requested?(:parameters)).to be_truthy
      expect(message.requested?(:maintenance_info)).to be_truthy
    end

    it 'builds the right message' do
      expect(message.name).to eq('my-service-instance')
      expect(message.service_plan_guid).to eq('service-plan-guid')
      expect(message.metadata[:labels]).to eq(potato: 'mashed')
      expect(message.metadata[:annotations]).to eq(cheese: 'bono')
      expect(message.tags).to contain_exactly('foo', 'bar', 'baz')
      expect(message.parameters).to match(foo: 'bar')
      expect(message.maintenance_info[:version]).to eq('1.3.3')
    end

    it 'accepts the empty request' do
      message = described_class.new({})
      expect(message).to be_valid
    end

    it 'can build an updates hash' do
      expect(message.updates).to eq({
        name: 'my-service-instance',
        service_plan_guid: 'service-plan-guid',
        tags: %w(foo bar baz)
      })

      expect(described_class.new({}).updates).to eq({})
    end

    describe 'validations' do
      it 'is invalid when there are unknown keys' do
        body[:type] = 'user-provided'
        expect(message).to_not be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'type'")
      end

      context 'name' do
        it 'must be a string' do
          body[:name] = 12

          message = described_class.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:name]).to include('must be a string')
        end
      end

      context 'tags' do
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

      context 'maintenance_info' do
        it 'must be an object' do
          body[:maintenance_info] = 42
          expect(message).to_not be_valid
          expect(message.errors[:maintenance_info]).to include('must be an object')
        end

        it 'is invalid when there are unknown fields' do
          body[:maintenance_info] = { something: 'other_info' }

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Maintenance info Unknown field(s): 'something'")
        end

        it 'is invalid when version is not semver' do
          body[:maintenance_info] = { version: 'other_info' }

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include(include('must be a Semantic Version string'))
        end

        it 'it can be empty' do
          body[:maintenance_info] = {}

          expect(message).to be_valid
        end

        it 'it can be nil' do
          body[:maintenance_info] = nil

          expect(message).to be_valid
        end

        it 'version can be nil' do
          body[:maintenance_info] = { version: nil }

          expect(message).to be_valid
        end
      end

      context 'parameters' do
        it 'must be an object' do
          body[:parameters] = 42
          expect(message).to_not be_valid
          expect(message.errors[:parameters]).to include('must be an object')
        end
      end

      context 'relationships' do
        it 'is invalid when there are unknown relationships' do
          body[:relationships][:service_offering] = { data: { guid: 'plan-guid' } }

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Relationships Unknown field(s): 'service_offering'")
        end

        it 'is invalid when guid is invalid' do
          body[:relationships] = { service_plan: { data: { guid: nil } } }

          expect(message).not_to be_valid
          expect(message.errors_on(:relationships)).to include('Service plan guid must be a string')
          expect(message.errors_on(:relationships)).to include('Service plan guid must be between 1 and 200 characters')
        end

        it 'is invalid when service plan is empty ' do
          body[:relationships] = { service_plan: {} }

          expect(message).not_to be_valid
          expect(message.errors_on(:relationships)).to include("Service plan can't be blank")
        end

        it 'is invalid when there are unexpected keys' do
          body[:relationships] = { service_plan: { data: { guid: 'some-guid' } }, potato: 'fried' }

          expect(message).not_to be_valid
          expect(message.errors_on(:relationships)).to include("Unknown field(s): 'potato'")
        end

        it 'is invalid when the relationships field is non-hash and non-nil' do
          body[:relationships] = 'something'

          expect(message).not_to be_valid
          expect(message.errors_on(:relationships)).to include('must be an object')
        end
      end
    end
  end
end
