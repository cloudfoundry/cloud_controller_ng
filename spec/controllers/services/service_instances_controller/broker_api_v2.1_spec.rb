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
            service_id:"service-guid-here",
            app_guid: app_guid
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

        it 'sends the app_guid as part of the request' do
          p request_from_cc_to_broker
          a_request(:put, %r(broker-url/v2/service_instances/#{@service_instance_guid}/service_bindings/#{binding_id_pattern})).
            with(body: request_from_cc_to_broker).
            should have_been_made
        end
      end
    end

    def request_has_version_header(method, url)
      versioned_request(method, url).
        with { |request| request.headers[api_header].should match(api_accepted_version) }.
        should have_been_made
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
  end
end
