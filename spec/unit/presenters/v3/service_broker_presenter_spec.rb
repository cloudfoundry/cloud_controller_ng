require 'spec_helper'
require 'presenters/v3/app_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ServiceBrokerPresenter do
    let(:space) { VCAP::CloudController::Space.make }
    let(:service_broker) do
      VCAP::CloudController::ServiceBroker.make(
        name: 'greg',
        broker_url: 'https://best-broker.io'
      )
    end

    describe '#to_hash' do
      let(:result) { ServiceBrokerPresenter.new(service_broker).to_hash }

      it 'presents the service broker as JSON' do
        expect(result[:guid]).to eq(service_broker.guid)
        expect(result[:name]).to eq(service_broker.name)
        expect(result[:url]).to eq(service_broker.broker_url)

        expect(result[:created_at]).to eq(service_broker.created_at)
        expect(result[:updated_at]).to eq(service_broker.updated_at)

        expect(result[:relationships].length).to eq(0)
      end

      it 'includes a link to itself in the JSON' do
        links = {
          self: { href: "#{link_prefix}/v3/service_brokers/#{service_broker.guid}" }
        }
        expect(result[:links]).to eq(links)
      end

      context 'when the service broker has an associated space' do
        let(:service_broker) do
          VCAP::CloudController::ServiceBroker.make(
            name: 'greg',
            space: space,
            broker_url: 'https://best-broker.io'
          )
        end

        it 'includes a space relationship in the JSON' do
          relationships = {
            space: { data: { guid: space.guid } }
          }
          expect(result[:relationships]).to eq(relationships)
        end

        it 'includes a space link in the JSON' do
          expect(result[:links][:space][:href]).to eq("#{link_prefix}/v3/spaces/#{space.guid}")
        end
      end
    end
  end
end
