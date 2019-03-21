require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.13' do
    include VCAP::CloudController::BrokerApiHelper

    let(:catalog) { default_catalog }

    before do
      setup_cc
      setup_broker(catalog)
      @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
    end

    describe 'configuration parameter schemas' do
      let(:draft_schema) { "http://json-schema.org/#{version}/schema#" }
      let(:create_instance_schema) { { '$schema' => draft_schema } }
      let(:update_instance_schema) { { '$schema' => draft_schema } }
      let(:create_binding_schema) { { '$schema' => draft_schema } }
      let(:schemas) {
        {
          'service_instance' => {
            'create' => {
              'parameters' => create_instance_schema
            },
            'update' => {
              'parameters' => update_instance_schema
            }
          },
          'service_binding' => {
            'create' => {
              'parameters' => create_binding_schema
            }
          }
        }
      }

      let(:catalog) { default_catalog(plan_schemas: schemas) }

      context 'v4' do
        let(:version) { 'draft-04' }

        context 'when a broker catalog defines a service instance' do
          context 'with a valid create schema' do
            let(:create_instance_schema) { { '$schema' => draft_schema } }

            it 'responds with the schema for a service plan entry' do
              get("/v2/service_plans/#{@plan_guid}",
                {}.to_json,
                json_headers(admin_headers))

              parsed_body = MultiJson.load(last_response.body)
              create_schema = parsed_body['entity']['schemas']['service_instance']['create']
              expect(create_schema).to eq({ 'parameters' => { '$schema' => draft_schema } })
            end
          end

          context 'with a valid update schema' do
            let(:update_instance_schema) {
              {
                '$schema' => draft_schema
              }
            }

            it 'responds with the schema for a service plan entry' do
              get("/v2/service_plans/#{@plan_guid}",
                {}.to_json,
                json_headers(admin_headers))

              parsed_body = MultiJson.load(last_response.body)
              update_schema = parsed_body['entity']['schemas']['service_instance']['update']
              expect(update_schema).to eq({ 'parameters' => { '$schema' => draft_schema } })
            end
          end

          context 'when the create schema is not a hash' do
            before do
              update_broker(default_catalog(plan_schemas: { 'service_instance' => { 'create' => true } }))
            end

            it 'returns an error' do
              parsed_body = MultiJson.load(last_response.body)

              expect(parsed_body['code']).to eq(270012)
              expect(parsed_body['description']).to include('Schemas service_instance.create must be a hash, but has value true')
            end
          end

          context 'when an update schema is not a hash' do
            before do
              update_broker(default_catalog(plan_schemas: { 'service_instance' => { 'update' => true } }))
            end

            it 'returns an error' do
              parsed_body = MultiJson.load(last_response.body)

              expect(parsed_body['code']).to eq(270012)
              expect(parsed_body['description']).to include('Schemas service_instance.update must be a hash, but has value true')
            end
          end
        end

        context 'when a broker catalog defines a service binding' do
          context 'with a valid create schema' do
            let(:create_binding_schema) { { '$schema' => draft_schema } }

            it 'responds with the schema for a service plan entry' do
              get("/v2/service_plans/#{@plan_guid}",
                {}.to_json,
                json_headers(admin_headers))

              parsed_body = MultiJson.load(last_response.body)
              create_schema = parsed_body['entity']['schemas']['service_binding']['create']
              expect(create_schema).to eq({ 'parameters' => { '$schema' => draft_schema } })
            end
          end

          context 'when a service binding create schema is not a hash' do
            before do
              update_broker(default_catalog(plan_schemas: { 'service_binding' => { 'create' => true } }))
            end

            it 'returns an error' do
              parsed_body = MultiJson.load(last_response.body)

              expect(parsed_body['code']).to eq(270012)
              expect(parsed_body['description']).to include('Schemas service_binding.create must be a hash, but has value true')
            end
          end
        end

        context 'when the broker catalog defines a plan without plan schemas' do
          it 'responds with an empty schema' do
            get("/v2/service_plans/#{@large_plan_guid}",
              {}.to_json,
              json_headers(admin_headers)
            )

            parsed_body = MultiJson.load(last_response.body)
            expect(parsed_body['entity']['schemas']).
              to eq(
                {
                  'service_instance' => {
                    'create' => {
                      'parameters' => {}
                    },
                    'update' => {
                      'parameters' => {}
                    }
                  },
                  'service_binding' => {
                    'create' => {
                      'parameters' => {}
                    }
                  }
                }
              )
          end
        end
      end

      context 'v6' do
        let(:version) { 'draft-06' }

        context 'when a broker catalog defines a service instance' do
          context 'with a valid create schema' do
            let(:create_instance_schema) { { '$schema' => draft_schema } }

            it 'responds with the schema for a service plan entry' do
              get("/v2/service_plans/#{@plan_guid}",
                  {}.to_json,
                  json_headers(admin_headers))

              parsed_body = MultiJson.load(last_response.body)
              create_schema = parsed_body['entity']['schemas']['service_instance']['create']
              expect(create_schema).to eq({ 'parameters' => { '$schema' => draft_schema } })
            end
          end

          context 'with a valid update schema' do
            let(:update_instance_schema) {
              {
                '$schema' => draft_schema
              }
            }

            it 'responds with the schema for a service plan entry' do
              get("/v2/service_plans/#{@plan_guid}",
                  {}.to_json,
                  json_headers(admin_headers))

              parsed_body = MultiJson.load(last_response.body)
              update_schema = parsed_body['entity']['schemas']['service_instance']['update']
              expect(update_schema).to eq({ 'parameters' => { '$schema' => draft_schema } })
            end
          end

          context 'when the create schema is not a hash' do
            before do
              update_broker(default_catalog(plan_schemas: { 'service_instance' => { 'create' => true } }))
            end

            it 'returns an error' do
              parsed_body = MultiJson.load(last_response.body)

              expect(parsed_body['code']).to eq(270012)
              expect(parsed_body['description']).to include('Schemas service_instance.create must be a hash, but has value true')
            end
          end

          context 'when an update schema is not a hash' do
            before do
              update_broker(default_catalog(plan_schemas: { 'service_instance' => { 'update' => true } }))
            end

            it 'returns an error' do
              parsed_body = MultiJson.load(last_response.body)

              expect(parsed_body['code']).to eq(270012)
              expect(parsed_body['description']).to include('Schemas service_instance.update must be a hash, but has value true')
            end
          end
        end
      end
    end

    describe 'originating header' do
      let(:catalog) { default_catalog(plan_updateable: true) }

      context 'service broker registration' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          setup_broker_with_user(user)
          @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:get, %r{/v2/catalog}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'service provision request' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          provision_service(user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'service deprovision request' do
        let(:user) { VCAP::CloudController::User.make }

        before do
          provision_service(user: user)
          deprovision_service(user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'service update request' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          provision_service(user: user)
          update_service_instance(200, user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:patch, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'service binding request' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          provision_service
          create_app
          bind_service(user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'service unbind request' do
        let(:user) { VCAP::CloudController::User.make }
        let(:async) { false }

        before do
          provision_service
          create_app
          bind_service
          unbind_service(user: user, async: async)
          VCAP::CloudController::SecurityContext.clear
          Delayed::Worker.new.work_off
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end

        context 'called with async=true' do
          let(:async) { true }

          it 'reports the request as enqueued' do
            parsed_body = MultiJson.load(last_response.body)
            expect(parsed_body).to_not be_empty
            expect(parsed_body).to include('entity')
            expect(parsed_body['entity']).to include('status' => 'queued')
          end

          it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
            base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

            expect(
              a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
                req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
              end
            ).to have_been_made
          end
        end
      end

      context 'create service key request' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          provision_service
          create_service_key(user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'delete service key request' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          provision_service
          create_service_key
          delete_key(user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'create route binding' do
        let(:catalog) { default_catalog(plan_updateable: true, requires: ['route_forwarding']) }
        let(:user) { VCAP::CloudController::User.make }
        let(:route) { VCAP::CloudController::Route.make(space: @space) }

        before do
          provision_service
          create_route_binding(route, user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'delete route binding' do
        let(:catalog) { default_catalog(plan_updateable: true, requires: ['route_forwarding']) }
        let(:user) { VCAP::CloudController::User.make }
        let(:route) { VCAP::CloudController::Route.make(space: @space) }

        before do
          provision_service
          create_route_binding(route, user: user)
          delete_route_binding(route, user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'when multiple users operate on a service instance' do
        let(:user_a) { VCAP::CloudController::User.make }
        let(:user_b) { VCAP::CloudController::User.make }
        let(:user_c) { VCAP::CloudController::User.make }

        before do
          provision_service(user: user_a)
          update_service_instance(200, user: user_b)
          deprovision_service(user: user_c)
        end

        it 'has the correct user ids for the requests' do
          base64_encoded_user_a_id = Base64.strict_encode64("{\"user_id\":\"#{user_a.guid}\"}")
          base64_encoded_user_b_id = Base64.strict_encode64("{\"user_id\":\"#{user_b.guid}\"}")
          base64_encoded_user_c_id = Base64.strict_encode64("{\"user_id\":\"#{user_c.guid}\"}")

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_a_id}"
            end
          ).to have_been_made

          expect(
            a_request(:patch, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_b_id}"
            end
          ).to have_been_made

          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_c_id}"
            end
          ).to have_been_made
        end
      end
    end

    describe 'service binding contains context object' do
      context 'for binding to an application' do
        before do
          provision_service
          create_app
          bind_service
        end

        it 'receives a context object' do
          expected_body = hash_including(:context)
          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_guid}}).with(body: expected_body)
          ).to have_been_made
        end

        it 'receives the correct attributes in the context' do
          expected_context_attributes = {
            'platform' => 'cloudfoundry',
            'organization_guid' => @org_guid,
            'space_guid' => @space_guid
          }

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_guid}}).with { |req|
              context = JSON.parse(req.body)['context']
              context >= expected_context_attributes
            }).to have_been_made
        end
      end

      context 'for create service key' do
        before do
          provision_service
          create_service_key
        end

        it 'receives a context object' do
          expected_body = hash_including(:context)
          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_guid}}).with(body: expected_body)
          ).to have_been_made
        end

        it 'receives the correct attributes in the context' do
          expected_context_attributes = {
            'platform' => 'cloudfoundry',
            'organization_guid' => @org_guid,
            'space_guid' => @space_guid
          }

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_guid}}).with { |req|
              context = JSON.parse(req.body)['context']
              context >= expected_context_attributes
            }).to have_been_made
        end
      end

      context 'for bind route service' do
        let(:catalog) { default_catalog(requires: ['route_forwarding']) }
        let(:route) { VCAP::CloudController::Route.make(space: @space) }
        before do
          provision_service
          create_route_binding(route)
        end

        it 'receives a context object' do
          expected_body = hash_including(:context)
          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_guid}}).with(body: expected_body)
          ).to have_been_made
        end

        it 'receives the correct attributes in the context' do
          expected_context_attributes = {
            'platform' => 'cloudfoundry',
            'organization_guid' => @org_guid,
            'space_guid' => @space_guid
          }

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_guid}}).with { |req|
              context = JSON.parse(req.body)['context']
              context >= expected_context_attributes
            }).to have_been_made
        end
      end
    end
  end
end
