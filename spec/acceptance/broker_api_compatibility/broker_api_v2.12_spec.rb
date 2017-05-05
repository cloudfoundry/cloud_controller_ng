require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.12' do
    include VCAP::CloudController::BrokerApiHelper

    let(:catalog) { default_catalog(plan_updateable: true) }

    before do
      setup_cc
      setup_broker(catalog)
      @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
    end

    context 'service provision request' do
      before do
        provision_service
      end

      it 'receives a context object' do
        expected_body = hash_including(:context)
        expect(
          a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}}).with(body: expected_body)
        ).to have_been_made
      end

      it 'receives the correct attributes in the context' do
        expected_body = hash_including(context: {
          platform: 'cloudfoundry',
          organization_guid: @org_guid,
          space_guid: @space_guid,
        })

        expect(
          a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}}).with(body: expected_body)
        ).to have_been_made
      end
    end

    context 'service update request' do
      before do
        provision_service
        upgrade_service_instance(200)
      end

      it 'receives a context object' do
        expected_body = hash_including(:context)

        expect(
          a_request(:patch, %r{/v2/service_instances/#{@service_instance_guid}}).with(body: expected_body)
        ).to have_been_made
      end

      it 'receives the correct attributes in the context' do
        expected_body = hash_including(context: {
          platform: 'cloudfoundry',
          organization_guid: @org_guid,
          space_guid: @space_guid,
        })

        expect(
          a_request(:patch, %r{/v2/service_instances/#{@service_instance_guid}}).with(body: expected_body)
        ).to have_been_made
      end
    end
  end
end
