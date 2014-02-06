
module VCAP::CloudController::BrokerApiHelper
  def request_has_version_header(method, url)
    a_request(method, url).
      with { |request| request.headers[api_header].should match(api_accepted_version) }.
      should have_been_made
  end

  def stub_catalog_fetch(broker_response_status=200, catalog = nil)
    catalog ||= {
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
    }

    stub_request(:get, 'http://username:password@broker-url/v2/catalog').to_return(
      status: broker_response_status,
      body: catalog.to_json)
  end

  def setup_cc
    org = VCAP::CloudController::Organization.make
    @org_guid = org.guid
    @space = VCAP::CloudController::Space.make(organization: org)
    @space_guid = @space.guid
  end

  def setup_broker(catalog = nil)
    if (catalog)
      stub_catalog_fetch(200, catalog)
    else
      stub_catalog_fetch
    end

    post('/v2/service_brokers',
      { name: 'broker-name', broker_url: 'http://broker-url', auth_username: 'username', auth_password: 'password' }.to_json,
      json_headers(admin_headers))
    response     = JSON.parse(last_response.body)
    @broker_guid = response['metadata']['guid']

    get('/v2/services?inline-relations-depth=1', '{}', json_headers(admin_headers))
    response   = JSON.parse(last_response.body)
    @plan_guid = response['resources'].first['entity']['service_plans'].find { |plan| plan['entity']['name']=='small' }['metadata']['guid']
    make_all_plans_public

    WebMock.reset!
  end

  def make_all_plans_public
    response           = get('/v2/service_plans', '{}', json_headers(admin_headers))
    service_plan_guids = JSON.parse(response.body).fetch('resources').map { |plan| plan.fetch('metadata').fetch('guid') }
    service_plan_guids.each do |service_plan_guid|
      put("/v2/service_plans/#{service_plan_guid}", JSON.dump(public: true), json_headers(admin_headers))
    end
  end

  def delete_broker
    delete("/v2/service_brokers/#{@broker_guid}", '{}', json_headers(admin_headers))
  end

  def provision_service
    body = { dashboard_url: "https://your.service.com/dashboard" }.to_json
    stub_request(:put, %r(broker-url/v2/service_instances/[[:alnum:]-]+)).
      to_return(status: 201, body: "#{body}")

    post('/v2/service_instances',
      {
        name:              'test-service',
        space_guid:        @space_guid,
        service_plan_guid: @plan_guid
      }.to_json,
      json_headers(admin_headers))

    response = JSON.parse(last_response.body)
    @service_instance_guid = response['metadata']['guid']
  end

  def create_app
    application = VCAP::CloudController::AppFactory.make(space: @space)
    @app_guid = application.guid
  end

  def bind_service
    stub_request(:put, %r(/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+)).
      to_return(status: 201, body: {}.to_json)

    post('/v2/service_bindings',
      { app_guid: app_guid, service_instance_guid: @service_instance_guid }.to_json,
      json_headers(admin_headers))

    @binding_id = JSON.parse(last_response.body)["metadata"]["guid"]
  end
end
