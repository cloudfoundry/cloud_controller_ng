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
      }.deep_merge(body_extra)
    end
    let(:body_extra) { {} }

    let(:message) { described_class.new(body) }

    it 'accepts the minimal keys' do
      expect(message).to be_valid
      expect(message).to be_requested(:relationships)
      expect(message).not_to be_requested(:parameters)
      expect(message).not_to be_requested(:metadata)
    end

    it 'builds the right message' do
      expect(message.service_instance_guid).to eq('service-instance-guid')
      expect(message.route_guid).to eq('route-guid')
    end

    context 'when the request has parameters' do
      let(:body_extra) do
        { parameters: { foo: 'bar' } }
      end

      it 'accepts the parameters key' do
        expect(message).to be_valid
        expect(message).to be_requested(:relationships)
        expect(message).to be_requested(:parameters)
      end

      it 'builds the right message' do
        expect(message.parameters).to eq({ foo: 'bar' })
      end
    end

    context 'when the request has metadata' do
      let(:body_extra) do
        {
          metadata: {
            labels: { foo: 'bar' },
            annotations: { foz: 'baz' }
          }
        }
      end

      it 'accepts the metadata key' do
        expect(message).to be_valid
        expect(message).to be_requested(:metadata)
      end

      it 'builds the right message' do
        expect(message.metadata).to eq({ labels: { foo: 'bar' }, annotations: { foz: 'baz' } })
      end
    end

    describe 'validations' do
      it 'is invalid when there are unknown keys' do
        body[:unknown] = 'foo'
        expect(message).not_to be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'unknown'")
      end

      describe 'service instance relationship' do
        it 'fails when not present' do
          body[:relationships][:service_instance] = nil
          message.valid?
          expect(message).not_to be_valid
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
          expect(message).not_to be_valid
          expect(message.errors[:relationships]).to include(
            "Route can't be blank",
            /Route must be structured like this.*/
          )
          expect(message.errors[:relationships].count).to eq(2)
        end
      end

      describe 'parameters' do
        it 'fails when not a hash' do
          body[:parameters] = 'hello'
          expect(message).not_to be_valid
          expect(message.errors[:parameters]).to include('must be an object')
        end
      end

      describe 'metadata' do
        let(:body_extra) do
          { metadata: { labels: 1, annotations: { '' => 'stop', '*this*' => 'stuff' } } }
        end

        it 'fails when not in the right format' do
          expect(message).not_to be_valid
          expect(message.errors[:metadata]).to contain_exactly(
            "'labels' is not an object",
            'annotation key error: key cannot be empty string',
            "annotation key error: '*this*' contains invalid characters"
          )
        end
      end
    end
  end
end
