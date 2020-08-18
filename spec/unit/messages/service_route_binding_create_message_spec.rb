require 'lightweight_spec_helper'
require 'messages/service_route_binding_create_message'

module VCAP::CloudController
  RSpec.describe ServiceRouteBindingCreateMessage do
    let(:body) do
      {
        relationships: {
          service_instance: {
            data: { guid: 'service-instance-guid' }
          },
          route: {
            data: { guid: 'route-guid' }
          }
        }
      }
    end

    let(:message) { described_class.new(body) }

    it 'accepts the allowed keys' do
      expect(message).to be_valid
      expect(message.requested?(:relationships)).to be_truthy
    end

    it 'builds the right message' do
      expect(message.service_instance_guid).to eq('service-instance-guid')
      expect(message.route_guid).to eq('route-guid')
    end

    describe 'validations' do
      it 'is invalid when there are unknown keys' do
        body[:parameters] = 'foo'
        expect(message).to_not be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'parameters'")
      end

      describe 'service instance relationship' do
        it 'fails when not present' do
          body[:relationships][:service_instance] = nil
          message.valid?
          expect(message).to_not be_valid
          expect(message.errors[:relationships]).to include(
            "Service instance can't be blank",
            /Service instance must be structured like this.*/
          )
          expect(message.errors[:relationships].count).to eq(2)
        end
      end

      describe 'route relationship' do
        it 'fails when not present' do
          body[:relationships][:route] = nil
          expect(message).to_not be_valid
          expect(message.errors[:relationships]).to include(
            "Route can't be blank",
            /Route must be structured like this.*/,
          )
          expect(message.errors[:relationships].count).to eq(2)
        end
      end
    end
  end
end
