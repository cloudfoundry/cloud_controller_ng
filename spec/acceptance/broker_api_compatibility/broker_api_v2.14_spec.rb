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
            get("/v2/service_bindings/#{@binding_guid}/parameters",
              {}.to_json,
              json_headers(admin_headers))
            parsed_body = MultiJson.load(last_response.body)
            expect(parsed_body['foo']).to eq 'bar'
          end

          it 'sends the broker the X-Broker-Api-Originating-Identity header' do
            user = VCAP::CloudController::User.make
            base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

            get("/v2/service_bindings/#{@binding_guid}/parameters",
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
        let(:url) { "http://#{stubbed_broker_host}/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+/last_operation" }

        context 'when bindings_retrievable is true' do
          let(:catalog) do
            catalog = default_catalog
            catalog[:services].first[:bindings_retrievable] = true
            catalog
          end

          it 'performs the flow asynchronously and fetches the last operation from the broker' do
            operation_data = 'some_operation_data'

            stub_async_last_operation(operation_data: operation_data, url: url)
            async_bind_service(status: 202, response_body: { operation: operation_data })

            service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_guid)
            expect(a_request(:put, service_binding_url(service_binding, 'accepts_incomplete=true'))).to have_been_made

            Delayed::Worker.new.work_off

            expect(a_request(:get,
                             "#{service_binding_url(service_binding)}/last_operation?operation=#{operation_data}&plan_id=plan1-guid-here&service_id=service-guid-here"
                            )).to have_been_made
          end

          context 'when the last operation is successful' do
            it 'fetches the service binding details' do
              stub_async_last_operation
              async_bind_service(status: 202)

              service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_guid)
              stub_request(:get, service_binding_url(service_binding)).to_return(status: 200, body: '{"credentials": {"foo": true}')

              Delayed::Worker.new.work_off

              get("/v2/service_bindings/#{@binding_guid}", '', admin_headers)
              response = JSON.parse(last_response.body)

              expect(response['entity']['last_operation']['state']).to eql('succeeded')
              expect(response['entity']['credentials']).to eql('foo' => true)
            end

            context 'when the get binding response' do
              let(:service_binding) { VCAP::CloudController::ServiceBinding.find(guid: @binding_guid) }

              before do
                stub_async_last_operation
                async_bind_service(status: 202, response_body: { operation: 'some-operation' })
              end

              context 'is invalid' do
                it 'set the last operation status to failed and does not perform orphan mitigation' do
                  stub_request(:get, service_binding_url(service_binding)).to_return(status: 200, body: 'invalid-response')

                  Delayed::Worker.new.work_off

                  expect(service_binding.last_operation.state).to eq('failed')
                  expect(a_request(:delete, "#{service_binding_url(service_binding)}?plan_id=plan1-guid-here&service_id=service-guid-here")).to_not have_been_made
                end
              end

              context 'is not 200' do
                it 'set the last operation status to failed and does not perform orphan mitigation' do
                  stub_request(:get, service_binding_url(service_binding)).to_return(status: 204, body: '{}')

                  Delayed::Worker.new.work_off

                  expect(service_binding.last_operation.state).to eq('failed')
                  expect(a_request(:delete, "#{service_binding_url(service_binding)}?plan_id=plan1-guid-here&service_id=service-guid-here")).to_not have_been_made
                end
              end

              context 'times out' do
                it 'set the last operation status to failed and does not perform orphan mitigation' do
                  stub_request(:get, service_binding_url(service_binding)).to_timeout

                  Delayed::Worker.new.work_off

                  expect(service_binding.last_operation.state).to eq('failed')
                  expect(a_request(:delete, "#{service_binding_url(service_binding)}?plan_id=plan1-guid-here&service_id=service-guid-here")).to_not have_been_made
                end
              end
            end
          end
        end
      end

      context 'when the broker returns synchronously' do
        it 'performs the synchronous flow' do
          async_bind_service(status: 201)

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+\?accepts_incomplete=true})
          ).to have_been_made

          service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_guid)
          expect(service_binding).not_to be_nil
        end
      end
    end

    describe 'update service dashboard url' do
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }
      let(:catalog) { default_catalog(plan_updateable: true) }

      before do
        @service_instance_guid = service_instance.guid
      end

      context 'when updating the instance asynchronously' do
        it 'updates the service instance with the new dashboard url' do
          async_update_service(dashboard_url: 'http://instance-dashboard.com')
          stub_async_last_operation

          expect(
            a_request(:patch, update_url_for_broker(@broker, accepts_incomplete: true))).to have_been_made

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

          Delayed::Worker.new.work_off

          expect(a_request(:get, %r{#{service_instance_url(service_instance)}/last_operation})).to have_been_made
          expect(service_instance.reload.last_operation.state).to eq 'succeeded'
          expect(service_instance.reload.dashboard_url).to eq 'http://instance-dashboard.com'
        end
      end

      context 'when updating the instance synchronously' do
        it 'updates the service instance with the new dashboard url' do
          update_service_instance(200, { dashboard_url: 'http://instance-dashboard.com' })

          expect(
            a_request(:patch, update_url_for_broker(@broker))).to have_been_made

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

          expect(service_instance.reload.dashboard_url).to eq 'http://instance-dashboard.com'
        end
      end
    end

    describe 'deleting service bindings asynchronously' do
      before do
        provision_service
        create_app
        bind_service
      end

      context 'when the broker returns asynchronously' do
        it 'performs the flow asynchronously and fetches the last operation from the broker' do
          operation_data = 'some_operation_data'

          stub_async_last_operation(operation_data: operation_data)
          async_unbind_service(status: 202, response_body: { operation: operation_data })

          service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_guid)
          expect(a_request(:delete, unbind_url(service_binding, accepts_incomplete: true))).to have_been_made

          Delayed::Worker.new.work_off

          expect(a_request(:get,
                           "#{service_binding_url(service_binding)}/last_operation?operation=#{operation_data}&plan_id=plan1-guid-here&service_id=service-guid-here"
                          )).to have_been_made
        end

        context 'when the last operation state is successful' do
          it 'deletes the binding' do
            operation_data = 'some_operation_data'

            stub_async_last_operation(operation_data: operation_data)
            async_unbind_service(status: 202, response_body: { operation: operation_data })

            Delayed::Worker.new.work_off

            get("/v2/service_bindings/#{@binding_guid}", '', admin_headers)

            expect(last_response.status).to eq(404)
          end
        end

        context 'when the last operation endpoint returns 410' do
          it 'deletes the binding' do
            operation_data = 'some_operation_data'

            stub_async_last_operation(operation_data: operation_data, return_code: 410)
            async_unbind_service(status: 202, response_body: { operation: operation_data })

            Delayed::Worker.new.work_off

            get("/v2/service_bindings/#{@binding_guid}", '', admin_headers)

            expect(last_response.status).to eq(404)
          end
        end
      end

      context 'when the broker returns synchronously' do
        it 'performs the synchronous flow' do
          unbind_service(status: 200, accepts_incomplete: true)

          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+})
          ).to have_been_made

          service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_guid)
          expect(service_binding).to be_nil
        end
      end
    end

    describe 'orphan mitigation strategy for 408s' do
      context 'when provisioning' do
        context 'when the broker responds with 408 (Client Timeout)' do
          before do
            stub_request(:put, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
              to_return(status: 408)

            body = {
              name: 'test-service',
              space_guid: @space_guid,
              service_plan_guid: @plan_guid
            }

            post('/v2/service_instances',
                 body.to_json,
                 admin_headers)

            Delayed::Worker.new.work_off
          end

          it 'should not orphan mitigate' do
            expect(
              a_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+})
            ).not_to have_been_made
          end
        end
      end

      context 'when binding' do
        before do
          provision_service
          create_app
        end

        context 'when the broker responds with 408 (Client Timeout)' do
          before do
            stub_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
              to_return(status: 408)

            body = { app_guid: @app_guid, service_instance_guid: @service_instance_guid }

            post('/v2/service_bindings',
                 body.to_json,
                 admin_headers)

            Delayed::Worker.new.work_off
          end

          it 'should not orphan mitigate' do
            expect(
              a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+})
            ).not_to have_been_made
          end
        end
      end

      context 'when creating a service key' do
        before do
          provision_service
          create_app
        end

        context 'when the broker responds with 408 (Client Timeout)' do
          before do
            stub_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
              to_return(status: 408)

            body = { name: 'service-key', service_instance_guid: @service_instance_guid }

            post('/v2/service_keys',
                 body.to_json,
                 admin_headers)

            Delayed::Worker.new.work_off
          end

          it 'should not orphan mitigate' do
            expect(
              a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+})
            ).not_to have_been_made
          end
        end
      end
    end

    describe 'orphan mitigation strategy for 422 ConcurrencyErrors' do
      context 'when provisioning' do
        before do
          stub_request(:put, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
            to_return(status: 422, body: { error: 'ConcurrencyError' }.to_json)

          body = {
            name: 'test-service',
            space_guid: @space_guid,
            service_plan_guid: @plan_guid
          }

          post('/v2/service_instances',
               body.to_json,
               admin_headers)

          Delayed::Worker.new.work_off
        end

        it 'should not orphan mitigate' do
          expect(
            a_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+})
          ).not_to have_been_made
        end
      end

      context 'when binding' do
        before do
          provision_service
          create_app
          stub_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
            to_return(status: 422, body: { error: 'ConcurrencyError' }.to_json)

          body = { app_guid: @app_guid, service_instance_guid: @service_instance_guid }

          post('/v2/service_bindings',
               body.to_json,
               admin_headers)

          Delayed::Worker.new.work_off
        end

        it 'should not orphan mitigate' do
          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+})
          ).not_to have_been_made
        end
      end

      context 'when creating a service key' do
        before do
          provision_service
          create_app
          stub_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
            to_return(status: 422, body: { error: 'ConcurrencyError' }.to_json)

          body = { name: 'service-key', service_instance_guid: @service_instance_guid }

          post('/v2/service_keys',
               body.to_json,
               admin_headers)

          Delayed::Worker.new.work_off
        end

        it 'should not orphan mitigate' do
          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+})
          ).not_to have_been_made
        end
      end
    end
  end
end
