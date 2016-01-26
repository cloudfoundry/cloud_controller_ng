require 'spec_helper'

describe 'Service Broker API integration' do
  describe 'v2.4' do
    include VCAP::CloudController::BrokerApiHelper

    before { setup_cc }

    let(:broker_url) { stubbed_broker_url }
    let(:broker_name) { 'broker-name' }
    let(:broker_auth_username) { stubbed_broker_username }
    let(:broker_auth_password) { stubbed_broker_password }
    let(:broker_response_status) { 200 }

    describe 'Updating the plan of a service instance' do
      let(:catalog) do
        {
          services: [{
            id:          'service-guid-here',
            name:        'MySQL',
            description: 'A MySQL-compatible relational database',
            bindable:    true,
            plan_updateable: true,
            plans: [{
              id:          'plan1-guid-here',
              name:        'small',
              description: 'A small shared database with 100mb storage quota and 10 connections'
            }, {
              id:          'plan2-guid-here',
              name:        'large',
              description: 'A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections'
            }]
          }]
        }
      end
      let(:create_broker_json) do
        {
          name: broker_name,
          broker_url: broker_url,
          auth_username: broker_auth_username,
          auth_password: broker_auth_password
        }.to_json
      end

      before do
        setup_broker(catalog)
      end

      context 'when the service update should succeed' do
        it 'successfully updates the service plan' do
          provision_service
          expect(VCAP::CloudController::ServiceInstance.find(guid: @service_instance_guid).service_plan_guid).to eq @plan_guid

          upgrade_service_instance(200)
          expect(last_response.status).to eq 201
          expect(VCAP::CloudController::ServiceInstance.find(guid: @service_instance_guid).service_plan_guid).to eq @large_plan_guid
        end
      end

      context 'when the service update fails with broker error 422' do
        it 'returns 502 to the client' do
          provision_service

          upgrade_service_instance(422)
          expect(last_response.status).to eq 502
        end
      end
    end
  end
end
