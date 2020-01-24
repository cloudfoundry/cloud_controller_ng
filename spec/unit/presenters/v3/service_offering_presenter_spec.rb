require 'spec_helper'
require 'support/link_helpers'
require 'presenters/v3/service_offering_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::ServiceOfferingPresenter do
  let(:guid) { 'some-offering-guid' }
  let(:name) { 'some-offering-name' }
  let(:description) { 'some offering description' }
  let(:available) { false }
  let(:bindable) { false }
  let(:extra) { '{"foo": "bar", "baz": {"answer": 42}' }
  let(:id) { 'broker-id' }
  let(:tags) { %w(foo bar) }
  let(:requires) { %w(syslog_drain route_forwarding volume_mount) }
  let(:updateable) { false }
  let(:service_broker) { VCAP::CloudController::ServiceBroker.make }
  let(:instances_retrievable) { false }
  let(:bindings_retrievable) { false }
  let(:created_at) { Time.now.round(0) - 100 }

  let(:service_offering) do
    VCAP::CloudController::Service.make(
      guid: guid,
      label: name,
      description: description,
      active: available,
      bindable: bindable,
      extra: extra,
      unique_id: id,
      tags: tags,
      requires: requires,
      plan_updateable: updateable,
      service_broker: service_broker,
      instances_retrievable: instances_retrievable,
      bindings_retrievable: bindings_retrievable,
      created_at: created_at
    )
  end

  describe '#to_hash' do
    let(:result) { described_class.new(service_offering).to_hash.deep_symbolize_keys }

    it 'presents the service offering as JSON' do
      expect(result).to match({
        'guid': guid,
        'name': name,
        'description': description,
        'available': available,
        'tags': tags,
        'requires': requires,
        'created_at': created_at,
        'updated_at': service_offering.updated_at,
        'shareable': false,
        'broker_catalog': {
          'id': id,
          'metadata': {
            'foo': 'bar',
            'baz': {
              'answer': 42,
            }
          },
          'features': {
            'plan_updateable': updateable,
            'bindable': bindable,
            'instances_retrievable': instances_retrievable,
            'bindings_retrievable': bindings_retrievable
          }
        },
        'links': {
          'self': {
            'href': "#{link_prefix}/v3/service_offerings/#{guid}"
          },
          'service_plans': {
            'href': "#{link_prefix}/v3/service_plans?service_offering_guids=#{guid}"
          },
          'service_broker': {
            'href': "#{link_prefix}/v3/service_brokers/#{service_broker.guid}"
          },
        },
        'relationships': {
          'service_broker': {
            'data': {
              'name': service_broker.name,
              'guid': service_broker.guid
            }
          }
        }
      })
    end

    context 'when `available` is true' do
      let(:available) { true }

      it 'displays `true``' do
        expect(result.dig(:available)).to be(true)
      end
    end

    context 'when `bindable` is true' do
      let(:bindable) { true }

      it 'displays `true``' do
        expect(result.dig(:broker_catalog, :features, :bindable)).to be(true)
      end
    end

    context 'when `updateable` is true' do
      let(:updateable) { true }

      it 'displays `true``' do
        expect(result.dig(:broker_catalog, :features, :plan_updateable)).to be(true)
      end
    end

    context 'when `instances_retrievable` is true' do
      let(:instances_retrievable) { true }

      it 'displays `true``' do
        expect(result.dig(:broker_catalog, :features, :instances_retrievable)).to be(true)
      end
    end

    context 'when `bindings_retrievable` is true' do
      let(:bindings_retrievable) { true }

      it 'displays `true``' do
        expect(result.dig(:broker_catalog, :features, :bindings_retrievable)).to be(true)
      end
    end

    context 'when `shareable` is true' do
      let(:extra) { '{"shareable": true}' }

      it 'displays `true``' do
        expect(result[:shareable]).to be true
      end
    end

    context 'when `shareable` is non-boolean' do
      let(:extra) { '{"shareable": "invalid value"}' }

      it 'displays `false``' do
        expect(result[:shareable]).to be false
      end
    end

    context 'when `shareable` is explicitly false' do
      let(:extra) { '{"shareable": false}' }

      it 'displays `false``' do
        expect(result[:shareable]).to be false
      end
    end

    context 'when `metadata` is not set' do
      let(:extra) { nil }

      it 'displays shareable as `false``' do
        expect(result[:shareable]).to be false
      end
    end

    # Note that the metadata is saved as a serialized JSON string, so it should always
    # be possible to parse it.
    context 'when the broker metadata cannot be parsed' do
      let(:extra) { 'this will cause a JSON parse error' }

      it 'defaults `shareable` to false' do
        expect(result[:shareable]).to be false
      end

      it 'defaults `metadata` to empty' do
        expect(result.dig(:broker_catalog, :metadata)).to be_empty
      end
    end
  end
end
