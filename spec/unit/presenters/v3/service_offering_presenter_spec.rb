require 'spec_helper'
require 'support/link_helpers'
require 'presenters/v3/service_offering_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::ServiceOfferingPresenter do
  let(:guid) { 'some-offering-guid' }
  let(:name) { 'some-offering-name' }
  let(:description) { 'some offering description' }
  let(:available) { true }
  let(:bindable) { true }
  let(:metadata) { '{"foo": "bar"}' }
  let(:id) { 'broker-id' }
  let(:tags) { %w(foo bar) }
  let(:requires) { %w(syslog_drain route_forwarding volume_mount) }
  let(:updateable) { true }
  let(:service_broker) { VCAP::CloudController::ServiceBroker.make }

  let(:service_offering) do
    VCAP::CloudController::Service.make(
      guid: guid,
      label: name,
      description: description,
      active: available,
      bindable: bindable,
      extra: metadata,
      unique_id: id,
      tags: tags,
      requires: requires,
      plan_updateable: updateable,
      service_broker: service_broker,
    )
  end

  describe '#to_hash' do
    let(:result) { described_class.new(service_offering).to_hash }

    it 'presents the service offering as JSON' do
      expect(result).to eq({
        'guid': guid,
        'name': name,
        'description': description,
        'available': available,
        'bindable': bindable,
        'broker_service_offering_metadata': metadata,
        'broker_service_offering_id': id,
        'tags': tags,
        'requires': requires,
        'created_at': service_offering.created_at,
        'updated_at': service_offering.updated_at,
        'plan_updateable': updateable,
        'shareable': false,
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

    context 'when the broker metadata contains a `shareable` field' do
      let(:metadata) { '{"shareable": true}' }

      it 'reads it' do
        expect(result[:shareable]).to be true
      end
    end

    context 'when the broker metadata cannot be parsed' do
      let(:metadata) { 'this will cause a JSON parse error' }

      it 'defaults `shareable` to false' do
        expect(result[:shareable]).to be false
      end
    end
  end
end
