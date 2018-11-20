require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.15' do
    include VCAP::CloudController::BrokerApiHelper

    before { setup_cc }

    describe 'updates service instances based on the plan object of the catalog' do
      context 'when the broker supports plan_updateable on plan level' do
        let(:catalog) do
          catalog = default_catalog
          catalog[:services].first[:plans].first[:plan_updateable] = true
          catalog
        end

        before do
          setup_broker(catalog)
        end

        it 'successfully updates the service instance plan' do
          provision_service
          expect(VCAP::CloudController::ServiceInstance.find(guid: @service_instance_guid).service_plan_guid).to eq @plan_guid

          update_service_instance(200)
          expect(last_response).to have_status_code(201)
          expect(VCAP::CloudController::ServiceInstance.find(guid: @service_instance_guid).service_plan_guid).to eq @large_plan_guid
        end
      end
    end
  end
end
