require 'spec_helper'

describe 'Service Broker API integration', type: :controller do
  describe 'v2.0' do
    before do
      VCAP::CloudController::Controller.any_instance.stub(:in_test_mode?).and_return(false)
    end

    let!(:org) { VCAP::CloudController::Organization.make }
    let!(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:space_guid) { space.guid }
    let(:org_guid) { org.guid }

    let(:api_header) { 'X-Broker-Api-Version' }
    let(:api_accepted_version) { /^2\.\d+$/ }

    let(:broker_url) { 'broker-url' }
    let(:broker_name) { 'broker-name' }
    let(:broker_auth_username) { 'username' }
    let(:broker_auth_password) { 'password' }

    describe 'Catalog Management' do
      describe 'fetching the catalog' do
        let(:username_pattern) { '[[:alnum:]-]+' }
        let(:password_pattern) { '[[:alnum:]-]+' }

        shared_examples 'a catalog fetch request' do
          it 'makes request to correct endpoint' do
            a_request(:get, 'http://username:password@broker-url/v2/catalog').should have_been_made
          end

          it 'sends basic auth info' do
            a_request(:get, %r(http://#{username_pattern}:#{password_pattern}@broker-url/v2/catalog)).should have_been_made
          end

          it 'uses correct version header' do
            request_has_version_header(:get, 'http://username:password@broker-url/v2/catalog')
          end
        end

        context 'when create-service-broker' do
          before do
            stub_catalog_fetch

            post('/v2/service_brokers',
              { name: broker_name, broker_url: 'http://' + broker_url, auth_username: broker_auth_username, auth_password: broker_auth_password }.to_json,
              json_headers(admin_headers))
          end

          it_behaves_like 'a catalog fetch request'

          it 'handles the broker response' do
            expect(last_response.status).to eq(201)
          end
        end

        context 'when update-service-broker' do
          let(:broker_guid) { @broker_info[0]}

          before(:all) do
            @broker_info = setup_broker
          end

          after(:all) do
            delete_broker(broker_guid)
          end

          before do
            stub_catalog_fetch

            put("/v2/service_brokers/#{broker_guid}",
              {}.to_json,
              json_headers(admin_headers))
          end

          it_behaves_like 'a catalog fetch request'

          it 'handles the broker response' do
            expect(last_response.status).to eq(200)
          end
        end
      end
    end

    describe 'Provisioning' do
      let(:guid_pattern) { '[[:alnum:]-]+' }
      let(:request_from_cc_to_broker) do
        {
          service_id:        'service-guid-here',
          plan_id:           'plan1-guid-here',
          organization_guid: org_guid,
          space_guid:        space_guid,
        }
      end

      # TODO: cleanup access to broker_info, set instance vars in setup_broker? find a way to completely remove instance vars?
      let(:broker_guid) { @broker_info[0]}
      let(:plan_guid) { @broker_info[1]}

      before(:all) do
        @broker_info = setup_broker
      end

      after(:all) do
        delete_broker(broker_guid)
      end

      describe 'service provision request' do
        let(:body) { '{}' }

        before do
          stub_request(:put, %r(#{broker_url}/v2/service_instances/#{guid_pattern})).
            to_return(status: 201, body: "#{body}")

          post('/v2/service_instances',
            {
              name:              'test-service',
              space_guid:        space_guid,
              service_plan_guid: plan_guid
            }.to_json,
            json_headers(admin_headers))
        end

        it 'sends all required fields' do
          a_request(:put, %r(broker-url/v2/service_instances/#{guid_pattern})).
            with(body: hash_including(request_from_cc_to_broker)).
            should have_been_made
        end

        it 'uses the correct version header' do
          request_has_version_header(:put, %r(broker-url/v2/service_instances/#{guid_pattern}))
        end

        it 'sends request with basic auth' do
          a_request(:put, %r(http://username:password@broker-url/v2/service_instances/#{guid_pattern})).should have_been_made
        end

        context 'when the response from broker does not contain a dashboard_url' do
          let(:body) { '{}' }

          it 'handles the broker response' do
            expect(last_response.status).to eq(201)
          end
        end

        context 'when the response from broker contains a dashboard_url' do
          let(:body) { '{"dashboard_url": "http://mongomgmthost/databases/9189kdfsk0vfnku?access_token=3hjdsnqadw487232lp"}' }

          it 'handles the broker response' do
            expect(last_response.status).to eq(201)
          end
        end
      end

      describe 'resource conflict during provision' do
        context 'when the broker returns a 409 "conflict"' do
          before do
            stub_request(:put, %r(http://#{broker_auth_username}:#{broker_auth_password}@#{broker_url}/v2/service_instances/#{guid_pattern})).
              to_return(status: 409, body: '{}')

            post('/v2/service_instances',
              { name: 'test-service', space_guid: space_guid, service_plan_guid: plan_guid }.to_json,
              json_headers(admin_headers)
            )
          end

          it 'makes the request to the broker' do
            a_request(:put, %r(http://username:password@broker-url/v2/service_instances/#{guid_pattern})).should have_been_made
          end

          it 'responds to user with 409' do
            expect(last_response.status).to eq(409)
          end
        end
      end
    end

    describe 'Binding' do
      let(:binding_id_pattern) { '[[:alnum:]-]+$' }
      let(:broker_response_status) { 200 }
      let(:broker_response_body) do
        {
          credentials: {
            uri:      "mysql://mysqluser:pass@mysqlhost:3306/dbname",
            username: "mysqluser",
            password: "pass",
            host:     "mysqlhost",
            port:     3306,
            database: "dbname"
          }
        }.to_json
      end
      let(:application) { VCAP::CloudController::AppFactory.make(space: space) }
      let(:app_guid) { application.guid }

      let(:broker_guid) { broker_info[0]}
      let(:plan_guid) { broker_info[1]}
      let(:broker_info) { setup_broker}

      after(:all) do
        delete_broker(broker_guid)
      end

      describe 'service binding request' do
        let(:request_from_cc_to_broker) do
          {
            plan_id: "plan1-guid-here",
            service_id:"service-guid-here"
          }
        end

        before do
          @service_instance_guid = provision_service(plan_guid, space_guid)

          stub_request(:put, %r(/v2/service_instances/#{@service_instance_guid}/service_bindings/#{binding_id_pattern})).
            to_return(status: broker_response_status, body: broker_response_body)

          post('/v2/service_bindings',
            { app_guid: app_guid, service_instance_guid: @service_instance_guid }.to_json,
            json_headers(admin_headers))
        end

        it 'uses the correct version header' do
          request_has_version_header(:put, %r(/v2/service_instances/#{@service_instance_guid}/service_bindings/#{binding_id_pattern}))
        end

        it 'sends request with basic auth' do
          a_request(:put, %r(http://username:password@broker-url/v2/service_instances/#{@service_instance_guid}/service_bindings/#{binding_id_pattern})).should have_been_made
        end

        it 'sends all required fields' do
          a_request(:put, %r(broker-url/v2/service_instances/#{@service_instance_guid}/service_bindings/#{binding_id_pattern})).
            with(body: hash_including(request_from_cc_to_broker)).
            should have_been_made
        end

        it 'makes a request' do
          a_request(:put, %r(/v2/service_instances/#{@service_instance_guid}/service_bindings/#{binding_id_pattern})).should have_been_made
        end

        context 'when broker responds with 200' do
          let(:broker_response_status) { 200 }

          it 'responds to user with 201' do
            expect(last_response.status).to eq(201)
          end
        end

        context 'when broker responds with 201' do
          let(:broker_response_status) { 201 }

          it 'responds to user with 201' do
            expect(last_response.status).to eq(201)
          end
        end

        context 'when broker responds with 409' do
          let(:broker_response_status) { 409 }

          it 'responds to user with 409' do
            expect(last_response.status).to eq(409)
          end
        end

        context 'when broker omits the - hash from its response' do
          let(:broker_response_body) { {}.to_json }

          it 'responds to user with 201' do
            expect(last_response.status).to eq(201)
          end
        end
      end
    end

    describe 'Unbinding' do
      let(:binding_id_pattern) { '[[:alnum:]-]+' }
      let(:broker_response_status) { 200 }
      let(:broker_response_body) do
       {}.to_json
      end
      let(:application) { VCAP::CloudController::AppFactory.make(space: space) }
      let(:app_guid) { application.guid }

      let(:broker_guid) { broker_info[0]}
      let(:plan_guid) { broker_info[1]}
      let(:broker_info) { setup_broker}

      after(:all) do
        delete_broker(broker_guid)
      end

      describe 'service unbinding request' do

        before do
          @service_instance_guid = provision_service(plan_guid, space_guid)
          @binding_id = bind_service(@service_instance_guid)

          stub_request(:delete, %r(/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_id})).
            to_return(status: broker_response_status, body: {}.to_json)

          delete("v2/service_bindings/#{@binding_id}",
            {}.to_json,
            json_headers(admin_headers)
          )
        end

        it 'sends all required fields' do
          a_request(:delete, %r(broker-url/v2/service_instances/#{@service_instance_guid}/service_bindings/#{binding_id_pattern}\?plan_id=plan1-guid-here&service_id=service-guid-here)).
            should have_been_made
        end

        context 'broker returns a 200 response' do
          let(:broker_response_status) { 200 }

          it 'returns a 204 response to user' do
            expect(last_response.status).to eq(204)
          end
        end

        context 'broker returns a 410 response' do
          let(:broker_response_status) { 410 }

          it 'returns a 204 response to user' do
            expect(last_response.status).to eq(204)
          end
        end

        context 'broker returns neither a 200 nor 410 response' do
          let(:broker_response_status) { 411 }

          # TODO: Should we check that CCDB still retains the instance?
          it 'returns a 500 response to user' do
            expect(last_response.status).to eq(500)
          end
        end
      end
    end

    describe 'Unprovisioning' do
      let(:broker_response_status) { 200 }
      let(:broker_response_body) do
        {}.to_json
      end

      let(:broker_guid) { broker_info[0] }
      let(:plan_guid) { broker_info[1] }
      let(:broker_info) { setup_broker }

      after(:all) do
        delete_broker(broker_guid)
      end

      describe 'service unprovision request' do
        before do
          @service_instance_guid = provision_service(plan_guid, space_guid)

          stub_request(:delete, %r(/v2/service_instances/#{@service_instance_guid})).
            to_return(status: broker_response_status, body: broker_response_body)

          delete("v2/service_instances/#{@service_instance_guid}",
            {}.to_json,
            json_headers(admin_headers)
          )
        end

        it 'sends all required fields' do
          a_request(:delete, %r(broker-url/v2/service_instances/#{@service_instance_guid}\?plan_id=plan1-guid-here&service_id=service-guid-here)).
            should have_been_made
        end

        context 'broker returns a 200 response' do
          let(:broker_response_status) { 200 }

          it 'returns a 204 response to user' do
            expect(last_response.status).to eq(204)
          end
        end

        context 'broker returns a 410 response' do
          let(:broker_response_status) { 410 }

          it 'returns a 204 response to user' do
            expect(last_response.status).to eq(204)
          end
        end

        context 'broker returns neither a 200 nor 410 response' do
          let(:broker_response_status) { 411 }

          it 'returns a 500 response to user' do
            expect(last_response.status).to eq(500)
          end
        end
      end
    end

    describe 'Broker Errors'
    describe 'Orphans'

    def request_has_version_header(method, url)
      a_request(method, url).
        with { |request| request.headers[api_header].should match(api_accepted_version) }.
        should have_been_made
    end

    def stub_catalog_fetch
      stub_request(:get, 'http://username:password@broker-url/v2/catalog').to_return(
        status: 200,
        body:
                {
                  services: [{
                    id:          "service-guid-here",
                    name:        "MySQL",
                    description: "A MySQL-compatible relational database",
                    bindable:    true,
                    plans:       [{
                      id:          "plan1-guid-here",
                      name:        "small",
                      description: "A small shared database with 100mb storage quota and 10 connections"
                    }, {
                      id:          "plan2-guid-here",
                      name:        "large",
                      description: "A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections"
                    }]
                  }]
                }.to_json)
    end

    def setup_broker
      stub_catalog_fetch

      post('/v2/service_brokers',
        { name: 'broker-name', broker_url: 'http://broker-url', auth_username: 'username', auth_password: 'password' }.to_json,
        json_headers(admin_headers))
      response    = JSON.parse(last_response.body)
      broker_guid = response['metadata']['guid']

      get('/v2/services?inline-relations-depth=1', '{}', json_headers(admin_headers))
      response        = JSON.parse(last_response.body)
      small_plan_guid = response['resources'].first['entity']['service_plans'].find { |plan| plan['entity']['name']=='small' }['metadata']['guid']

      make_all_plans_public

      WebMock.reset!

      return [broker_guid, small_plan_guid]
    end

    def make_all_plans_public
      response           = get('/v2/service_plans', '{}', json_headers(admin_headers))
      service_plan_guids = JSON.parse(response.body).fetch('resources').map { |plan| plan.fetch('metadata').fetch('guid') }
      service_plan_guids.each do |service_plan_guid|
        put("/v2/service_plans/#{service_plan_guid}", JSON.dump(public: true), json_headers(admin_headers))
      end
    end

    def delete_broker(broker_guid)
      delete("/v2/service_brokers/#{broker_guid}", '{}', json_headers(admin_headers))
    end

    def provision_service(plan_guid, space_guid)
      guid_pattern = '[[:alnum:]-]+'
      broker_url = 'broker-url'
      body = { dashboard_url: "https://your.service.com/dashboard" }.to_json
      stub_request(:put, %r(#{broker_url}/v2/service_instances/#{guid_pattern})).
        to_return(status: 201, body: "#{body}")

      post('/v2/service_instances',
        {
          name:              'test-service',
          space_guid:        space_guid,
          service_plan_guid: plan_guid
        }.to_json,
        json_headers(admin_headers))

      response = JSON.parse(last_response.body)
      service_instance_guid = response['metadata']['guid']
      service_instance_guid
    end

    def bind_service(service_instance_guid)
      broker_response_status = 201
      binding_id_pattern = '[[:alnum:]-]+'

      stub_request(:put, %r(/v2/service_instances/#{service_instance_guid}/service_bindings/#{binding_id_pattern})).
        to_return(status: broker_response_status, body: {}.to_json)

      post('/v2/service_bindings',
        { app_guid: app_guid, service_instance_guid: service_instance_guid }.to_json,
        json_headers(admin_headers))

      JSON.parse(last_response.body)["metadata"]["guid"]
    end
  end
end