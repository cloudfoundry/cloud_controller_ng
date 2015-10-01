module VCAP::CloudController::BrokerApiHelper
  def service_name
    'MySQL'
  end

  def stubbed_broker_url
    "http://#{stubbed_broker_host}"
  end

  def stubbed_broker_host
    'broker-url'
  end

  def stubbed_broker_username
    'username'
  end

  def stubbed_broker_password
    'password'
  end

  def stub_catalog_fetch(broker_response_status=200, catalog=nil)
    catalog ||= default_catalog

    stub_request(:get, "http://#{stubbed_broker_username}:#{stubbed_broker_password}@#{stubbed_broker_host}/v2/catalog").to_return(
      status: broker_response_status,
      body: catalog.to_json)
  end

  def default_catalog(plan_updateable: false)
    {
      services: [
        {
          id: 'service-guid-here',
          name: service_name,
          description: 'A MySQL-compatible relational database',
          bindable: true,
          plan_updateable: plan_updateable,
          plans: [
            {
              id: 'plan1-guid-here',
              name: 'small',
              description: 'A small shared database with 100mb storage quota and 10 connections'
            }, {
              id: 'plan2-guid-here',
              name: 'large',
              description: 'A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections'
            }
          ]
        }
      ]
    }
  end

  def setup_cc
    org = VCAP::CloudController::Organization.make
    @org_guid = org.guid
    @space = VCAP::CloudController::Space.make(organization: org)
    @space_guid = @space.guid
  end

  def setup_broker(catalog=nil)
    stub_catalog_fetch(200, catalog)

    post('/v2/service_brokers',
         { name: 'broker-name', broker_url: 'http://broker-url', auth_username: 'username', auth_password: 'password' }.to_json,
         json_headers(admin_headers))
    response = JSON.parse(last_response.body)
    @broker_guid = response['metadata']['guid']

    get('/v2/services?inline-relations-depth=1', '{}', json_headers(admin_headers))
    response = JSON.parse(last_response.body)
    service_plans = response['resources'].first['entity']['service_plans']
    @plan_guid = service_plans.find { |plan| plan['entity']['name'] == 'small' }['metadata']['guid']

    large_plan = service_plans.find { |plan| plan['entity']['name'] == 'large' }
    @large_plan_guid = large_plan['metadata']['guid'] if large_plan
    make_all_plans_public

    WebMock.reset!
  end

  def update_broker(catalog)
    stub_catalog_fetch(200, catalog)

    put("/v2/service_brokers/#{@broker_guid}", '{}', json_headers(admin_headers))
  end

  def make_all_plans_public
    response = get('/v2/service_plans', '{}', json_headers(admin_headers))
    service_plan_guids = JSON.parse(response.body).fetch('resources').map { |plan| plan.fetch('metadata').fetch('guid') }
    service_plan_guids.each do |service_plan_guid|
      put("/v2/service_plans/#{service_plan_guid}", JSON.dump(public: true), json_headers(admin_headers))
    end
  end

  def delete_broker
    delete("/v2/service_brokers/#{@broker_guid}", '{}', json_headers(admin_headers))
  end

  def async_delete_service(status: 202)
    stub_request(:delete, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
      to_return(status: status, body: '{}')

    delete("/v2/service_instances/#{@service_instance_guid}?accepts_incomplete=true",
      {}.to_json,
      json_headers(admin_headers))
  end

  def async_provision_service(status: 202)
    stub_request(:put, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
      to_return(status: status, body: "#{{ dashboard_url: 'https://your.service.com/dashboard' }.to_json}")

    body = {
      name: 'test-service',
      space_guid: @space_guid,
      service_plan_guid: @plan_guid
    }

    post('/v2/service_instances?accepts_incomplete=true',
      body.to_json,
      json_headers(admin_headers))

    response = JSON.parse(last_response.body)
    @service_instance_guid = response['metadata']['guid']
  end

  def stub_async_last_operation(state: 'succeeded')
    fetch_body = {
      state: state

    }

    stub_request(:get,
      "http://#{stubbed_broker_username}:#{stubbed_broker_password}@#{stubbed_broker_host}/v2/service_instances/#{@service_instance_guid}/last_operation").
      to_return(
      status: 200,
      body: fetch_body.to_json)
  end

  def provision_service(opts={})
    return_code = opts.delete(:return_code) || 201
    stub_request(:put, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
      to_return(status: return_code, body: "#{{ dashboard_url: 'https://your.service.com/dashboard' }.to_json}")

    body = {
      name: 'test-service',
      space_guid: @space_guid,
      service_plan_guid: @plan_guid
    }
    if opts[:parameters]
      body[:parameters] = opts[:parameters]
    end

    post('/v2/service_instances',
         body.to_json,
         json_headers(admin_headers))

    response = JSON.parse(last_response.body)
    @service_instance_guid = response['metadata']['guid']
  end

  def upgrade_service_instance(return_code, opts={})
    stub_request(:patch, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).to_return(status: return_code, body: '{}')

    body = {
      service_plan_guid: @large_plan_guid
    }
    if opts[:parameters]
      body[:parameters] = opts[:parameters]
    end

    put("/v2/service_instances/#{@service_instance_guid}",
        body.to_json,
        json_headers(admin_headers)
    )
  end

  def async_update_service(status: 202)
    stub_request(:patch, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
      to_return(status: status, body: '{}')

    body = {
      service_plan_guid: @large_plan_guid
    }

    put("/v2/service_instances/#{@service_instance_guid}?accepts_incomplete=true",
      body.to_json,
      json_headers(admin_headers))
  end

  def create_app
    application = VCAP::CloudController::AppFactory.make(space: @space)
    @app_guid = application.guid
  end

  def bind_service(opts={})
    stub_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
      to_return(status: 201, body: {}.to_json)

    body = { app_guid: @app_guid, service_instance_guid: @service_instance_guid }
    if opts[:parameters]
      body[:parameters] = opts[:parameters]
    end

    post('/v2/service_bindings',
         body.to_json,
         json_headers(admin_headers)
    )

    @binding_id = JSON.parse(last_response.body)['metadata']['guid']
  end

  def unbind_service
    stub_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
      to_return(status: 204, body: {}.to_json)

    delete("/v2/service_bindings/#{@binding_id}",
      '{}',
      json_headers(admin_headers)
    )
  end

  def create_service_key(opts={})
    stub_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
      to_return(status: 201, body: {}.to_json)

    body = { service_instance_guid: @service_instance_guid, name: 'test-key' }
    if opts[:parameters]
      body[:parameters] = opts[:parameters]
    end

    post('/v2/service_keys',
         body.to_json,
         json_headers(admin_headers)
    )

    @service_key_id = JSON.parse(last_response.body)['metadata']['guid']
  end

  def delete_key
    stub_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
      to_return(status: 204, body: {}.to_json)

    delete("/v2/service_keys/#{@service_key_id}",
      '{}',
      json_headers(admin_headers)
    )
  end

  def deprovision_service
    stub_request(:delete, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
      to_return(status: 200, body: '{}')

    delete("/v2/service_instances/#{@service_instance_guid}", '{}', json_headers(admin_headers))
  end
end
