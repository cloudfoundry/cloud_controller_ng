require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.0' do
    include VCAP::CloudController::BrokerApiHelper

    before { setup_cc }

    let(:space_guid) { @space_guid }
    let(:org_guid) { @org_guid }

    let(:api_header) { 'X-Broker-Api-Version' }
    let(:api_accepted_version) { /^2\.\d+$/ }

    let(:broker_url) { 'broker-url' }
    let(:broker_name) { 'broker-name' }
    let(:broker_auth_username) { 'username' }
    let(:broker_auth_password) { 'password' }
    let(:broker_response_status) { 200 }

    let(:guid_pattern) { '[[:alnum:]-]+' }

    def request_has_version_header(method, url)
      expect(a_request(method, url).
          with { |request| expect(request.headers[api_header]).to match(api_accepted_version) }).
        to have_been_made
    end

    shared_examples 'broker errors' do
      context 'when broker returns 400' do
        let(:broker_response_status) { 400 }

        it 'returns an error to the user' do
          expect(last_response).to have_status_code(502)
        end
      end
      context 'when broker returns 401' do
        let(:broker_response_status) { 401 }

        it 'returns an error to the user' do
          expect(last_response).to have_status_code(502)
        end
      end
      context 'when broker returns 403' do
        let(:broker_response_status) { 403 }

        it 'returns an error to the user' do
          expect(last_response).to have_status_code(502)
        end
      end
      context 'when broker returns 422' do
        let(:broker_response_status) { 422 }

        it 'returns an error to the user' do
          expect(last_response).to have_status_code(502)
        end
      end
      context 'when broker returns 502' do
        let(:broker_response_status) { 502 }

        it 'returns an error to the user' do
          expect(last_response).to have_status_code(502)
        end
      end
      context 'when broker returns 500' do
        let(:broker_response_status) { 500 }

        it 'returns an error to the user' do
          expect(last_response).to have_status_code(502)
        end
      end
    end

    describe 'Catalog Management' do
      describe 'fetching the catalog' do
        let(:username_pattern) { '[[:alnum:]-]+' }
        let(:password_pattern) { '[[:alnum:]-]+' }

        shared_examples 'a catalog fetch request' do
          it 'makes request to correct endpoint' do
            expect(a_request(:get, 'http://username:password@broker-url/v2/catalog')).to have_been_made
          end

          it 'sends basic auth info' do
            expect(a_request(:get, %r{http://#{username_pattern}:#{password_pattern}@broker-url/v2/catalog})).to have_been_made
          end

          it 'uses correct version header' do
            request_has_version_header(:get, 'http://username:password@broker-url/v2/catalog')
          end
        end

        context 'when create-service-broker' do
          before do
            stub_catalog_fetch(broker_response_status)

            post('/v2/service_brokers', {
                name: broker_name,
                broker_url: 'http://' + broker_url,
                auth_username: broker_auth_username,
                auth_password: broker_auth_password
              }.to_json,
              json_headers(admin_headers))
          end

          it_behaves_like 'a catalog fetch request'

          include_examples 'broker errors'

          it 'handles the broker response' do
            expect(last_response).to have_status_code(201)
          end
        end

        context 'when update-service-broker' do
          before { setup_broker }
          after { delete_broker }

          before do
            stub_catalog_fetch(broker_response_status)

            put("/v2/service_brokers/#{@broker_guid}",
              {}.to_json,
              json_headers(admin_headers))
          end

          it_behaves_like 'a catalog fetch request'

          include_examples 'broker errors'

          it 'handles the broker response' do
            expect(last_response).to have_status_code(200)
          end
        end
      end
    end

    describe 'Provisioning' do
      let(:plan_guid) { @plan_guid }
      let(:request_from_cc_to_broker) do
        {
          service_id:        'service-guid-here',
          plan_id:           'plan1-guid-here',
          organization_guid: org_guid,
          space_guid:        space_guid,
        }
      end

      before { setup_broker }
      after { delete_broker }

      describe 'service provision request' do
        let(:broker_response_body) { '{}' }
        let(:broker_response_status) { 201 }

        before do
          stub_request(:put, %r{#{broker_url}/v2/service_instances/#{guid_pattern}}).
            to_return(status: broker_response_status, body: broker_response_body)

          stub_request(:delete, %r{#{broker_url}/v2/service_instances/#{guid_pattern}}).
            to_return(status: broker_response_status, body: broker_response_body)

          post('/v2/service_instances',
            {
              name:              'test-service',
              space_guid:        space_guid,
              service_plan_guid: plan_guid
            }.to_json,
            json_headers(admin_headers))
        end

        include_examples 'broker errors'

        it 'sends all required fields' do
          expect(a_request(:put, %r{broker-url/v2/service_instances/#{guid_pattern}}).
            with(body: hash_including(request_from_cc_to_broker))).
            to have_been_made
        end

        it 'uses the correct version header' do
          request_has_version_header(:put, %r{broker-url/v2/service_instances/#{guid_pattern}})
        end

        it 'sends request with basic auth' do
          expect(a_request(:put, %r{http://username:password@broker-url/v2/service_instances/#{guid_pattern}})).to have_been_made
        end

        context 'when the response from broker does not contain a dashboard_url' do
          let(:broker_response_body) { '{}' }

          it 'handles the broker response' do
            expect(last_response).to have_status_code(201)
          end
        end

        context 'when the response from broker contains a dashboard_url' do
          let(:broker_response_body) { '{"dashboard_url": "http://mongomgmthost/databases/9189kdfsk0vfnku?access_token=3hjdsnqadw487232lp"}' }

          it 'handles the broker response' do
            expect(last_response).to have_status_code(201)
          end
        end

        context 'when the broker returns a 409 "conflict"' do
          let(:broker_response_status) { 409 }

          it 'makes the request to the broker' do
            expect(a_request(:put, %r{http://username:password@broker-url/v2/service_instances/#{guid_pattern}})).to have_been_made
          end

          it 'responds to user with 409' do
            expect(last_response).to have_status_code(409)
          end
        end
      end
    end

    describe 'Binding' do
      let(:broker_response_status) { 200 }
      let(:broker_response_body) do
        {
          credentials: {
            uri:      'mysql://mysqluser:pass@mysqlhost:3306/dbname',
            username: 'mysqluser',
            password: 'pass',
            host:     'mysqlhost',
            port:     3306,
            database: 'dbname'
          }
        }.to_json
      end
      let(:app_guid) { @app_guid }
      let(:service_instance_guid) { @service_instance_guid }
      let(:request_from_cc_to_broker) do
        {
          plan_id: 'plan1-guid-here',
          service_id: 'service-guid-here'
        }
      end

      before do
        setup_broker
        provision_service
        create_app
      end

      after do
        delete_broker
      end

      describe 'service binding request' do
        before do
          stub_request(:put, %r{/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}}).
            to_return(status: broker_response_status, body: broker_response_body)

          post('/v2/service_bindings',
            { app_guid: app_guid, service_instance_guid: service_instance_guid }.to_json,
            json_headers(admin_headers))
        end

        include_examples 'broker errors'

        it 'uses the correct version header' do
          request_has_version_header(:put, %r{/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}$})
        end

        it 'sends request with basic auth' do
          expect(a_request(:put, %r{http://username:password@broker-url/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}$})).
            to have_been_made
        end

        it 'sends all required fields' do
          expect(a_request(:put, %r{broker-url/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}$}).
            with(body: hash_including(request_from_cc_to_broker))).
            to have_been_made
        end

        it 'makes a request' do
          expect(a_request(:put, %r{/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}$})).to have_been_made
        end

        context 'when broker responds with 200' do
          let(:broker_response_status) { 200 }

          it 'responds to user with 201' do
            expect(last_response).to have_status_code(201)
          end
        end

        context 'when broker responds with 201' do
          let(:broker_response_status) { 201 }

          it 'responds to user with 201' do
            expect(last_response).to have_status_code(201)
          end
        end

        context 'when broker responds with 409 conflict' do
          let(:broker_response_status) { 409 }

          it 'responds to user with 409' do
            expect(last_response).to have_status_code(409)
          end
        end

        context 'when broker does not return credentials' do
          let(:broker_response_body) { {}.to_json }

          it 'responds to user with 201' do
            expect(last_response).to have_status_code(201)
          end
        end
      end
    end

    describe 'Unbinding' do
      let(:broker_response_status) { 200 }
      let(:broker_response_body) { '{}' }
      let(:app_guid) { @app_guid }
      let(:service_instance_guid) { @service_instance_guid }
      let(:binding_id) { @binding_id }

      before do
        setup_broker
        provision_service
        create_app
        bind_service
      end

      after do
        delete_broker
      end

      describe 'service unbinding request' do
        before do
          stub_request(:delete, %r{/v2/service_instances/#{service_instance_guid}/service_bindings/#{binding_id}}).
            to_return(status: broker_response_status, body: '{}')

          delete("v2/service_bindings/#{binding_id}",
            '{}',
            json_headers(admin_headers)
          )
        end

        include_examples 'broker errors'

        it 'sends all required fields' do
          expected_url = %r{broker-url/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}\?plan_id=plan1-guid-here&service_id=service-guid-here}
          expect(a_request(:delete, expected_url)).to have_been_made
        end

        context 'broker returns a 200 response' do
          let(:broker_response_status) { 200 }

          it 'returns a 204 response to user' do
            expect(last_response).to have_status_code(204)
          end
        end

        context 'broker returns a 410 response' do
          let(:broker_response_status) { 410 }

          it 'returns a 204 response to user' do
            expect(last_response).to have_status_code(204)
          end
        end

        context 'broker returns neither a 200 nor 410 response' do
          let(:broker_response_status) { 411 }

          it 'returns a 502 response to user' do
            expect(last_response).to have_status_code(502)
          end
        end
      end
    end

    describe 'Unprovisioning' do
      let(:broker_response_status) { 200 }
      let(:broker_response_body) { '{}' }
      let(:service_instance_guid) { @service_instance_guid }

      before do
        setup_broker
        provision_service
      end

      after do
        delete_broker
      end

      describe 'service unprovision request' do
        before do
          stub_request(:delete, %r{/v2/service_instances/#{service_instance_guid}}).
            to_return(status: broker_response_status, body: broker_response_body)

          delete("v2/service_instances/#{service_instance_guid}",
            '{}',
            json_headers(admin_headers)
          )
        end

        include_examples 'broker errors'

        it 'sends all required fields' do
          expect(a_request(:delete, %r{broker-url/v2/service_instances/#{service_instance_guid}\?plan_id=plan1-guid-here&service_id=service-guid-here})).
            to have_been_made
        end

        context 'broker returns a 200 response' do
          let(:broker_response_status) { 200 }

          it 'returns a 204 response to user' do
            expect(last_response).to have_status_code(204)
          end
        end

        context 'broker returns a 410 response' do
          let(:broker_response_status) { 410 }

          it 'returns a 204 response to user' do
            expect(last_response).to have_status_code(204)
          end
        end

        context 'broker returns neither a 200 nor 410 response' do
          let(:broker_response_status) { 411 }

          it 'returns a 502 response to user' do
            expect(last_response).to have_status_code(502)
          end
        end
      end
    end
  end
end
