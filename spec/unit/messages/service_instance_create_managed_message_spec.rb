require 'lightweight_spec_helper'
require 'messages/service_instance_create_managed_message'

module VCAP::CloudController
  RSpec.describe ServiceInstanceCreateManagedMessage do
    let(:body) do
      {
        type: 'managed',
        name: 'my-service-instance',
        parameters: { foo: 'bar' },
        tags: %w[foo bar baz],
        relationships: {
          space: {
            data: { guid: 'space-guid' }
          },
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
      expect(message).to be_requested(:type)
      expect(message).to be_requested(:name)
      expect(message).to be_requested(:relationships)
      expect(message).to be_requested(:tags)
      expect(message).to be_requested(:parameters)
    end

    it 'builds the right message' do
      expect(message.type).to eq('managed')
      expect(message.name).to eq('my-service-instance')
      expect(message.space_guid).to eq('space-guid')
      expect(message.service_plan_guid).to eq('service-plan-guid')
      expect(message.metadata[:labels]).to eq(potato: 'mashed')
      expect(message.metadata[:annotations]).to eq(cheese: 'bono')
      expect(message.tags).to contain_exactly('foo', 'bar', 'baz')
      expect(message.parameters).to match(foo: 'bar')
    end

    it 'accepts the minimal request' do
      message = described_class.new(
        type: 'managed',
        name: 'my-service-instance',
        relationships: {
          space: {
            data: { guid: 'space-guid' }
          },
          service_plan: {
            data: { guid: 'service-plan-guid' }
          }
        }
      )
      expect(message).to be_valid
    end

    describe 'validations' do
      it 'is invalid when there are unknown keys' do
        body[:bogus] = 'field'
        expect(message).not_to be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
      end

      describe 'type' do
        it 'must be `managed`' do
          body[:type] = 'user-provided'
          expect(message).not_to be_valid
          expect(message.errors[:type]).to include("must be 'managed'")
        end
      end

      describe 'parameters' do
        it 'must be an object' do
          body[:parameters] = 42
          expect(message).not_to be_valid
          expect(message.errors[:parameters]).to include('must be an object')
        end
      end

      describe 'service plan relationship' do
        it 'fails when not present' do
          body[:relationships][:service_plan] = nil
          message.valid?
          expect(message).not_to be_valid
          expect(message.errors[:relationships]).to include(
            "Service plan can't be blank",
            /Service plan must be structured like this.*/
          )
          expect(message.errors[:relationships].count).to eq(2)
        end
      end

      describe 'space relationship' do
        it 'fails when not present' do
          body[:relationships][:space] = nil
          expect(message).not_to be_valid
          expect(message.errors[:relationships]).to include(
            "Space can't be blank",
            /Space must be structured like this.*/
          )
          expect(message.errors[:relationships].count).to eq(2)
        end
      end
    end
  end
end
