require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.6' do
    include VCAP::CloudController::BrokerApiHelper

    describe 'Send service_id with each request' do
      let(:catalog) { default_catalog plan_updateable: true }
      let(:service_id) { catalog[:services].first[:id] }

      before do
        setup_cc
        setup_broker(catalog)
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
      end

      it 'sends service_id to broker for provision' do
        provision_service

        expected_body = hash_including({ 'service_id' => service_id })
        expect(
          a_request(:put, provision_url_for_broker(@broker)).with(body: expected_body)
        ).to have_been_made
      end

      context 'there is a service instance' do
        before do
          provision_service
        end

        it 'sends service_id for service instance update' do
          upgrade_service_instance(200)
          expected_body = hash_including({ 'service_id' => service_id })

          expect(
            a_request(:patch, update_url_for_broker(@broker)).with(body: expected_body)
          ).to have_been_made
        end

        it 'sends service_id to broker for service instance deprovision' do
          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

          deprovision_service
          expect(
            a_request(:delete, deprovision_url(service_instance)).with(body: {})
          ).to have_been_made
        end

        it 'sends service_id to broker for service instance bind' do
          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
          create_app
          bind_service

          expected_body = hash_including({ 'service_id' => service_id })
          expect(
            a_request(:put, bind_url(service_instance)).with(body: expected_body)
          ).to have_been_made
        end

        it 'sends service_id to broker for service instance key creation' do
          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
          create_service_key

          expected_body = hash_including({ 'service_id' => service_id })
          expect(
            a_request(:put, bind_url(service_instance)).with(body: expected_body)
          ).to have_been_made
        end

        it 'sends service_id to broker for service instance unbind' do
          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
          create_app
          bind_service
          service_binding = service_instance.service_bindings.first

          unbind_service
          expect(
            a_request(:delete, unbind_url(service_binding)).with(body: {})
          ).to have_been_made
        end

        it 'sends service_id to broker for service instance key deletion' do
          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
          create_service_key
          service_key = service_instance.service_keys.first

          delete_key
          expect(
            a_request(:delete, unbind_url(service_key)).with(body: {})
          ).to have_been_made
        end
      end
    end

    describe 'Service key requests' do
      let(:catalog) { default_catalog plan_updateable: true }

      before do
        setup_cc
        setup_broker(catalog)
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
        provision_service
      end

      it 'does not require app_guid to be sent with provision' do
        service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
        expect(VCAP::CloudController::App.find(guid: @app_guid)).to be_nil
        create_service_key

        expect(
          a_request(:put, bind_url(service_instance)).with(body: {})
        ).to have_been_made
      end
    end
  end
end
