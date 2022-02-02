require 'lightweight_spec_helper'
require 'support/link_helpers'
require 'presenters/v3/service_broker_presenter'

module VCAP::CloudController
  module Presenters::V3
    RSpec.describe ServiceBrokerPresenter do
      include LinkHelpers

      before do
        StubConfig.prepare(
          self,
          {
            external_protocol: 'http',
            external_domain: 'api.example.org'
          }
        )
      end

      let(:service_broker_guid) { 'some-broker-guid' }
      let(:space_guid) { nil }
      let(:service_broker) do
        double(
          guid: service_broker_guid,
          name: 'greg',
          broker_url: 'https://best-broker.io',
          auth_username: 'username',
          auth_password: 'welcome',
          space_guid: space_guid,
          created_at: Time.now,
          updated_at: Time.now,
          labels: [label],
          annotations: [annotation]
        )
      end

      let(:label) do
        double(
          resource_guid: service_broker_guid,
          key_prefix: 'mr',
          key_name: 'potato',
          value: 'baked'
        )
      end

      let(:annotation) do
        double(
          resource_guid: service_broker_guid,
          key_prefix: 'u',
          key_name: 'style',
          value: 'mashed'
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

          expect(result[:metadata][:labels].length).to eq(1)
          expect(result[:metadata][:labels]).to eq({ 'mr/potato' => 'baked' })

          expect(result[:metadata][:annotations].length).to eq(1)
          expect(result[:metadata][:annotations]).to eq({ 'u/style' => 'mashed' })

          expect(result[:relationships].length).to eq(0)
        end

        it 'includes the right links' do
          links = {
            self: { href: "#{link_prefix}/v3/service_brokers/#{service_broker.guid}" },
            service_offerings: { href: "#{link_prefix}/v3/service_offerings?service_broker_guids=#{service_broker.guid}" },
          }

          expect(result[:links]).to eq(links)
        end

        context 'when the service broker has an associated space' do
          let(:space_guid) { 'some-space-guid' }

          it 'includes a space relationship in the JSON' do
            relationships = {
              space: { data: { guid: space_guid } }
            }
            expect(result[:relationships]).to eq(relationships)
          end

          it 'includes a space link in the JSON' do
            expect(result[:links][:space][:href]).to eq("#{link_prefix}/v3/spaces/#{space_guid}")
          end
        end
      end
    end
  end
end
