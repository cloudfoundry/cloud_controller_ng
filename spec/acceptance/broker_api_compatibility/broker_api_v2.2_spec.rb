require 'spec_helper'

describe 'Service Broker API integration' do
  describe 'v2.2' do
    include VCAP::CloudController::BrokerApiHelper

    before { setup_cc }

    let(:broker_url) { stubbed_broker_url }
    let(:broker_name) { 'broker-name' }
    let(:broker_auth_username) { stubbed_broker_username }
    let(:broker_auth_password) { stubbed_broker_password }
    let(:broker_response_status) { 200 }

    describe 'Catalog Management' do
      describe 'fetching the catalog' do
        let(:username_pattern) { '[[:alnum:]-]+' }
        let(:password_pattern) { '[[:alnum:]-]+' }

        let(:catalog) do
          {
            services: [{
              id:          'service-guid-here',
              name:        'MySQL',
              description: 'A MySQL-compatible relational database',
              bindable:    true,
              plans: [{
                id:          'plan1-guid-here',
                name:        'small',
                description: 'A small shared database with 100mb storage quota and 10 connections',
                free:        true
              }, {
                id:          'plan2-guid-here',
                name:        'large',
                description: 'A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections',
                free:        false
              }]
            }]
          }
        end

        context 'when create-service-broker' do
          after { delete_broker }
          before do
            stub_catalog_fetch(broker_response_status, catalog)

            post('/v2/service_brokers', {
              name: broker_name,
              broker_url: broker_url,
              auth_username: broker_auth_username,
              auth_password: broker_auth_password
            }.to_json,
              json_headers(admin_headers))
          end

          it 'handles the free field on service plans' do
            expect(last_response.status).to eq(201)
          end
        end

        context 'when update-service-broker' do
          after { delete_broker }
          before do
            setup_broker(catalog)

            stub_catalog_fetch(broker_response_status, catalog)

            put("/v2/service_brokers/#{@broker_guid}",
              {}.to_json,
              json_headers(admin_headers))
          end

          it 'handles the free field on service plans' do
            expect(last_response.status).to eq(200)
          end
        end
      end
    end
  end
end
