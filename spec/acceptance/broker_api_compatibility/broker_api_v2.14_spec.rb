require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.14' do
    include VCAP::CloudController::BrokerApiHelper
    let(:catalog) { default_catalog }

    before do
      setup_cc
      setup_broker(catalog)
      @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
    end

    describe 'fetching service binding configuration parameters' do
      context 'when the brokers catalog has bindings_retrievable set to true' do
        let(:catalog) do
          catalog = default_catalog
          catalog[:services].first[:bindings_retrievable] = true
          catalog
        end

        it 'is set to true on the service resource' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['bindings_retrievable']).to eq true
        end

        context 'and returns a parameters object' do
          before do
            provision_service
            create_app
            bind_service

            stub_request(:get, %r{broker-url/v2/service_instances/[[:alnum:]-]+/service_bindings/[[:alnum:]-]+}).
              to_return(status: 200, body: '{"parameters": {"foo":"bar"}}')
          end

          it 'should be retrievable' do
            get("/v2/service_bindings/#{@binding_id}/parameters",
              {}.to_json,
              json_headers(admin_headers))
            parsed_body = MultiJson.load(last_response.body)
            expect(parsed_body['foo']).to eq 'bar'
          end

          it 'sends the broker the X-Broker-Api-Originating-Identity header' do
            user = VCAP::CloudController::User.make
            base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

            get("/v2/service_bindings/#{@binding_id}/parameters",
              {}.to_json,
              headers_for(user, scopes: %w(cloud_controller.admin)))

            expect(
              a_request(:get, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
                req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
              end
            ).to have_been_made
          end
        end
      end

      context 'when the brokers catalog has bindings_retrievable set to false' do
        let(:catalog) do
          catalog = default_catalog
          catalog[:services].first[:bindings_retrievable] = false
          catalog
        end

        it 'is set to false on the service resource' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['bindings_retrievable']).to eq false
        end
      end

      context 'when the brokers catalog does not set bindings_retrievable' do
        it 'defaults to false on the service resource' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['bindings_retrievable']).to eq false
        end
      end
    end

    describe 'fetching service instance configuration parameters' do
      context 'when the brokers catalog has instances_retrievable set to true' do
        let(:catalog) do
          catalog = default_catalog
          catalog[:services].first[:instances_retrievable] = true
          catalog
        end

        it 'returns true' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['instances_retrievable']).to eq true
        end
      end

      context 'when the brokers catalog has instances_retrievable set to false' do
        let(:catalog) do
          catalog = default_catalog
          catalog[:services].first[:instances_retrievable] = false
          catalog
        end

        it 'shows the service as instances_retrievable false' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['instances_retrievable']).to eq false
        end
      end

      context 'when the brokers catalog does not set instances_retrievable' do
        it 'defaults to false' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['instances_retrievable']).to eq false
        end
      end
    end

    describe 'creating service bindings asynchronously' do
      before do
        provision_service
        create_app
      end

      context 'when the broker returns asynchronously' do
        it 'performs the asynchronously flow and fetches the last operation from the broker' do
          operation_data = 'some_operation_data'

          stub_async_binding_last_operation(operation_data: operation_data)
          async_bind_service(status: 202, response_body: { operation: operation_data })

          service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_id)
          expect(a_request(:put, service_binding_url(service_binding, 'accepts_incomplete=true'))).to have_been_made

          # service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
          # Delayed::Worker.new.work_off
          #
          expect(a_request(:get,
            "#{service_binding_url(service_binding)}/last_operation?operation=#{operation_data}&plan_id=plan1-guid-here&service_id=service-guid-here"
          )).to have_been_made
        end

        context 'when the broker returns synchronously' do
          it 'performs the synchronous flow' do
            async_bind_service(status: 201)

            expect(
              a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+\?accepts_incomplete=true})
            ).to have_been_made

            service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_id)
            expect(service_binding).not_to be_nil
          end
        end
      end
    end
  end
end
