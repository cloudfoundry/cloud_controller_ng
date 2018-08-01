require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.5' do
    include VCAP::CloudController::BrokerApiHelper

    describe 'Arbitrary Parameters' do
      let(:catalog) { default_catalog plan_updateable: true }
      let(:parameters) { { 'foo' => 'bar' } }

      before do
        setup_cc
        setup_broker(catalog)
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
      end

      it 'sends params to broker for service instance provision' do
        provision_service parameters: parameters
        expected_body = hash_including({ 'parameters' => parameters })

        expect(
          a_request(:put, provision_url_for_broker(@broker)).with(body: expected_body)
        ).to have_been_made
      end

      it 'sends params to broker for service instance update' do
        provision_service
        upgrade_service_instance(200, parameters: parameters)
        expected_body = hash_including({ 'parameters' => parameters })

        expect(
          a_request(:patch, update_url_for_broker(@broker)).with(body: expected_body)
        ).to have_been_made
      end

      it 'sends params to broker for service instance bind' do
        provision_service
        service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

        create_app
        bind_service parameters: parameters

        expected_body = hash_including({ 'parameters' => parameters })
        expect(
          a_request(:put, bind_url(service_instance)).with(body: expected_body)
        ).to have_been_made
      end

      it 'sends params to broker for service instance key creation' do
        provision_service
        service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

        create_service_key parameters: parameters

        expected_body = hash_including({ 'parameters' => parameters })
        expect(
          a_request(:put, bind_url(service_instance)).with(body: expected_body)
        ).to have_been_made
      end
    end
  end
end
