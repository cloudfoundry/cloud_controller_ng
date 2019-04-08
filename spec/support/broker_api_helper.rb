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

  def stub_catalog_fetch(broker_response_status=200, catalog=nil, broker_host=stubbed_broker_host)
    catalog ||= default_catalog

    stub_request(:get, "http://#{broker_host}/v2/catalog").
      with(basic_auth: [stubbed_broker_username, stubbed_broker_password]).
      to_return(
        status: broker_response_status,
        body: catalog.to_json)
  end

  def default_catalog(plan_updateable: false, requires: [], plan_schemas: {}, bindings_retrievable: false, maximum_polling_duration: nil, allow_context_updates: false)
    {
      services: [
        {
          id: 'service-guid-here',
          name: service_name,
          description: 'A MySQL-compatible relational database',
          bindable: true,
          requires: requires,
          plan_updateable: plan_updateable,
          bindings_retrievable: bindings_retrievable,
          allow_context_updates: allow_context_updates,
          plans: [
            {
              id: 'plan1-guid-here',
              name: 'small',
              description: 'A small shared database with 100mb storage quota and 10 connections',
              schemas: plan_schemas,
              maximum_polling_duration: maximum_polling_duration,
            },
            {
              id: 'plan2-guid-here',
              name: 'large',
              description: 'A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections'
            }
          ]
        }
      ]
    }
  end

  def small_catalog
    {
      services: [
        {
          id: 'other-id',
          name: 'Redis',
          description: 'A Redis-thing',
          bindable: true,
          requires: [],
          plan_updateable: false,
          plans: [
            {
              id: 'plan1-redis-guid-here',
              name: 'small',
              description: 'A small shared cache with 100mb storage quota and 10 connections',
              schemas: {}
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
    UAARequests.stub_all

    post('/v2/service_brokers',
         { name: 'broker-name', broker_url: 'http://broker-url', auth_username: 'username', auth_password: 'password' }.to_json,
         admin_headers)
    response = JSON.parse(last_response.body)
    @broker_guid = response['metadata']['guid']

    get('/v2/services?inline-relations-depth=1', '{}', admin_headers)
    response = JSON.parse(last_response.body)
    @service_guid = response['resources'].first['metadata']['guid']

    service_plans = response['resources'].first['entity']['service_plans']
    @plan_guid = service_plans.find { |plan| plan['entity']['name'] == 'small' }['metadata']['guid']

    large_plan = service_plans.find { |plan| plan['entity']['name'] == 'large' }
    @large_plan_guid = large_plan['metadata']['guid'] if large_plan
    make_all_plans_public

    WebMock.reset!
  end

  def setup_broker_with_user(user)
    stub_catalog_fetch(200, small_catalog, 'other-broker-url')
    UAARequests.stub_all

    headers = admin_headers_for(user)

    post('/v2/service_brokers',
         { name: 'other-broker-name', broker_url: 'http://other-broker-url', auth_username: 'username', auth_password: 'password' }.to_json,
         headers)
    response = JSON.parse(last_response.body)
    @broker_guid = response['metadata']['guid']
  end

  def update_broker(catalog)
    stub_catalog_fetch(200, catalog)

    put("/v2/service_brokers/#{@broker_guid}", '{}', admin_headers)
  end

  def make_all_plans_public
    response = get('/v2/service_plans', '{}', admin_headers)
    service_plan_guids = JSON.parse(response.body).fetch('resources').map { |plan| plan.fetch('metadata').fetch('guid') }
    service_plan_guids.each do |service_plan_guid|
      put("/v2/service_plans/#{service_plan_guid}", JSON.dump(public: true), admin_headers)
    end
  end

  def delete_broker
    delete("/v2/service_brokers/#{@broker_guid}", '{}', admin_headers)
  end

  def delete_service(status: 200, broker_response_body: '{}', accepts_incomplete: false)
    stub_request(:delete, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
      to_return(status: status, body: broker_response_body)

    delete("/v2/service_instances/#{@service_instance_guid}?accepts_incomplete=#{accepts_incomplete}",
           {}.to_json,
           admin_headers)
  end

  def async_delete_service(status: 202, broker_response_body: '{}')
    delete_service(status: status, broker_response_body: broker_response_body, accepts_incomplete: true)
  end

  def async_provision_service(status: 202, operation_data: nil)
    provision_response_body = { dashboard_url: 'https://your.service.com/dashboard' }
    if !operation_data.nil?
      provision_response_body[:operation] = operation_data
    end
    stub_request(:put, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
      to_return(status: status, body: provision_response_body.to_json)

    body = {
      name: 'test-service',
      space_guid: @space_guid,
      service_plan_guid: @plan_guid
    }

    post('/v2/service_instances?accepts_incomplete=true',
         body.to_json,
         admin_headers)

    response = JSON.parse(last_response.body)
    @service_instance_guid = response['metadata']['guid']
    last_response
  end

  def stub_async_last_operation(body: { state: 'succeeded' }, operation_data: nil, return_code: 200, url: '', headers: {})
    if !operation_data.nil?
      url += "\\?operation=#{operation_data}"
    end

    stub_request(:get,
      Regexp.new(url)).
      with(basic_auth: [stubbed_broker_username, stubbed_broker_password]).
      to_return(
        status: return_code,
        body: body.to_json,
        headers: headers
    )
  end

  def provision_service(opts={})
    return_code = opts.delete(:return_code) || 201
    stub_request(:put, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
      to_return(status: return_code, body: { dashboard_url: 'https://your.service.com/dashboard' }.to_json)

    body = {
      name: opts[:name] || 'test-service',
      space_guid: @space_guid,
      service_plan_guid: @plan_guid
    }
    if opts[:parameters]
      body[:parameters] = opts[:parameters]
    end

    headers = opts[:user] ? admin_headers_for(opts[:user]) : admin_headers

    post('/v2/service_instances',
         body.to_json,
         headers)

    response = JSON.parse(last_response.body)
    @service_instance_guid = response['metadata']['guid']
  end

  def rename_service_instance(return_code, opts={})
    stub_request(:patch, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).to_return(status: return_code, body: {}.to_json)

    put("/v2/service_instances/#{@service_instance_guid}",
        { name: opts[:name] || 'new-name' }.to_json,
        admin_headers
    )
  end

  def update_service_instance(return_code, opts={})
    broker_update_response_body = {}

    if opts[:dashboard_url]
      broker_update_response_body[:dashboard_url] = opts[:dashboard_url]
    end

    broker_url = @broker_url || 'broker-url'
    stub_request(:patch, %r{#{broker_url}/v2/service_instances/[[:alnum:]-]+}).to_return(status: return_code, body: broker_update_response_body.to_json)

    body = {
      service_plan_guid: @large_plan_guid
    }
    body[:parameters] = opts[:parameters] if opts[:parameters]
    body = opts[:body] if opts[:body]

    headers = opts[:user] ? admin_headers_for(opts[:user]) : admin_headers
    headers = opts[:headers] if opts[:headers]

    put("/v2/service_instances/#{@service_instance_guid}",
        body.to_json,
        headers
    )
  end

  def async_update_service(status: 202, operation_data: nil, dashboard_url: nil, maintenance_info: nil)
    broker_update_response_body = {}

    if operation_data
      broker_update_response_body[:operation] = operation_data
    end

    if dashboard_url
      broker_update_response_body[:dashboard_url] = dashboard_url
    end

    stub_request(:patch, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
      to_return(status: status, body: broker_update_response_body.to_json)

    body = { service_plan_guid: @large_plan_guid }
    body = { maintenance_info: maintenance_info } if maintenance_info

    put("/v2/service_instances/#{@service_instance_guid}?accepts_incomplete=true",
        body.to_json,
        admin_headers)
  end

  def create_app
    process = VCAP::CloudController::ProcessModelFactory.make(space: @space)
    @app_guid = process.guid
  end

  def bind_service(opts={})
    status = opts[:status] || 201
    res_body = opts[:response_body] || {}
    stub_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
      to_return(status: status, body: res_body.to_json)

    body = { app_guid: @app_guid, service_instance_guid: @service_instance_guid }
    if opts[:parameters]
      body[:parameters] = opts[:parameters]
    end

    headers = opts[:user] ? admin_headers_for(opts[:user]) : admin_headers
    query_params = opts[:accepts_incomplete] ? '?accepts_incomplete=' + opts[:accepts_incomplete] : ''

    post('/v2/service_bindings' + query_params,
         body.to_json,
         headers
    )

    metadata = JSON.parse(last_response.body).fetch('metadata', {})
    @binding_guid = metadata.fetch('guid', nil)

    last_response
  end

  def async_bind_service(opts={})
    opts[:accepts_incomplete] = 'true'
    opts[:status] = opts[:status] || 202
    bind_service(opts)
  end

  def async_unbind_service(opts={})
    opts[:accepts_incomplete] = 'true'
    opts[:status] = opts[:status] || 202
    unbind_service(opts)
  end

  def unbind_service(opts={})
    status = opts[:status] || 200
    res_body = opts[:response_body] || {}
    stub_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
      to_return(status: status, body: res_body.to_json)

    headers = opts[:user] ? admin_headers_for(opts[:user]) : admin_headers
    params = opts[:async] ? { async: true } : '{}'
    params = opts[:accepts_incomplete] ? { accepts_incomplete: true } : params
    delete("/v2/service_bindings/#{@binding_guid}", params, headers)
  end

  def create_service_key(opts={})
    stub_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
      to_return(status: 201, body: {}.to_json)

    body = { service_instance_guid: @service_instance_guid, name: 'test-key' }
    if opts[:parameters]
      body[:parameters] = opts[:parameters]
    end

    headers = opts[:user] ? admin_headers_for(opts[:user]) : admin_headers
    post('/v2/service_keys',
         body.to_json,
         headers
    )

    @service_key_id = JSON.parse(last_response.body)['metadata']['guid']
  end

  def delete_key(opts={})
    stub_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
      to_return(status: 204, body: {}.to_json)

    headers = opts[:user] ? admin_headers_for(opts[:user]) : admin_headers
    delete("/v2/service_keys/#{@service_key_id}",
           '{}',
           headers
    )
  end

  def deprovision_service(opts={})
    headers = opts[:user] ? admin_headers_for(opts[:user]) : admin_headers

    stub_request(:delete, %r{broker-url/v2/service_instances/[[:alnum:]-]+}).
      to_return(status: 200, body: '{}')

    delete("/v2/service_instances/#{@service_instance_guid}", '{}', headers)
  end

  def create_route_binding(route, opts={})
    stub_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
      to_return(status: 201, body: { route_service_url: 'https://example.com' }.to_json)

    headers = opts[:user] ? admin_headers_for(opts[:user]) : admin_headers

    put("/v2/service_instances/#{@service_instance_guid}/routes/#{route.guid}",
        '{}',
        headers
    )
  end

  def delete_route_binding(route, opts={})
    stub_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).
      to_return(status: 200, body: '{}')

    headers = opts[:user] ? admin_headers_for(opts[:user]) : admin_headers

    delete("/v2/service_instances/#{@service_instance_guid}/routes/#{route.guid}",
           nil,
           headers
    )
  end
end
