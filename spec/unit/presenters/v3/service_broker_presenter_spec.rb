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

      let(:service_broker_state) { nil }
      let(:space_guid) { nil }
      let(:service_broker) do
        double(
          guid: 'some-broker-guid',
          name: 'greg',
          broker_url: 'https://best-broker.io',
          auth_username: 'username',
          auth_password: 'welcome',
          space_guid: space_guid,
          service_broker_state: service_broker_state,
          created_at: Time.now,
          updated_at: Time.now
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

        describe 'broker status' do
          context 'when there is no state (e.g. legacy V2 created broker)' do
            it 'is available' do
              expect(result[:available]).to be(true)
              expect(result[:status]).to eq('available')
            end
          end

          context 'when state is available' do
            let(:service_broker_state) { double(state: ServiceBrokerStateEnum::AVAILABLE) }

            it 'is available' do
              expect(result[:available]).to be(true)
              expect(result[:status]).to eq('available')
            end
          end

          context 'when state is synchronizing' do
            let(:service_broker_state) { double(state: ServiceBrokerStateEnum::SYNCHRONIZING) }

            it 'is not available and has synchronization in progress' do
              expect(result[:available]).to be(false)
              expect(result[:status]).to eq('synchronization in progress')
            end
          end

          context 'when state is synchronization failed' do
            let(:service_broker_state) { double(state: ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED) }

            it 'is not available and has synchronization failed' do
              expect(result[:available]).to be(false)
              expect(result[:status]).to eq('synchronization failed')
            end
          end

          context 'when state is delete in progress' do
            let(:service_broker_state) { double(state: ServiceBrokerStateEnum::DELETE_IN_PROGRESS) }

            it 'is not available and has delete in progress' do
              expect(result[:available]).to be(false)
              expect(result[:status]).to eq('delete in progress')
            end
          end

          context 'when state is delete failed' do
            let(:service_broker_state) { double(state: ServiceBrokerStateEnum::DELETE_FAILED) }

            it 'is not available and has delete failed' do
              expect(result[:available]).to be(false)
              expect(result[:status]).to eq('delete failed')
            end
          end
        end
      end
    end
  end
end
