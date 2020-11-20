require 'spec_helper'
require 'cloud_controller'

# This lifecycle test aims to use different v3 service endpoints together
RSpec.describe 'V3 service route bindings synoptic' do
  before do
    stub_request(:get, 'http://example.org/amazing-service-broker/v2/catalog').
      with(basic_auth: %w(admin password)).
      to_return(status: 200, body: catalog, headers: {})

    stub_request(:put, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 201, body: {}.to_json, headers: {})

    stub_request(:get, 'https://master.default.svc.cluster-domain.example/apis/networking.cloudfoundry.org/v1alpha1').
      with(basic_auth: %w(admin password)).
      to_return(status: 200, body: '', headers: {})

    stub_request(:get, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+/service_bindings/.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 200, body: { parameters: { key1: 'value1', key2: 'value2' } }.to_json, headers: {})

    stub_request(:delete, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+/service_bindings/.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 410, body: '', headers: {})
    VCAP::CloudController::Config.config.set(:kubernetes, nil)
  end

  it 'works end to end' do
    org_guid = create_org
    space_guid = create_space(org_guid)

    post '/v3/service_brokers', create_service_broker_request_body.to_json, admin_headers
    expect(last_response).to have_status_code(202)
    execute_all_jobs(expected_successes: 1, expected_failures: 0)

    plan_guid = get_route_service_plan using: admin_headers
    make_plan_visible plan_guid

    service_instance_guid = wait_for_service_instance_to_be_created(space_guid, plan_guid)

    domain_guid = create_domain
    route_guid = create_route(domain_guid, space_guid)

    create_request = create_route_binding_request(route_guid, service_instance_guid)
    post '/v3/service_route_bindings', create_request.to_json, admin_headers
    expect(last_response).to have_status_code(202)
    execute_all_jobs(expected_successes: 1, expected_failures: 0)

    get '/v3/service_route_bindings', nil, admin_headers
    route_binding_guid = parsed_response['resources'][0]['guid']
    get "/v3/service_route_bindings/#{route_binding_guid}/parameters", nil, admin_headers
    expect(parsed_response).to contain_exactly(*create_request[:parameters].with_indifferent_access)

    update_request = {
      metadata: {
        labels: { key: 'value' },
        annotations: { note: 'detailed information' }
      }
    }
    patch "/v3/service_route_bindings/#{route_binding_guid}", update_request.to_json, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['metadata']['annotations']).to contain_exactly(*update_request[:metadata][:annotations].merge(create_request[:metadata][:annotations]).stringify_keys)
    expect(parsed_response['metadata']['labels']).to contain_exactly(*update_request[:metadata][:labels].merge(create_request[:metadata][:labels]).stringify_keys)

    delete "/v3/service_route_bindings/#{route_binding_guid}", nil, admin_headers
    expect(last_response).to have_status_code(202)
    execute_all_jobs(expected_successes: 1, expected_failures: 0)
    get "/v3/service_route_bindings/#{route_binding_guid}", nil, admin_headers
    expect(last_response).to have_status_code(404)
  end

  def create_org
    org_request_body = { name: 'my-organization' }

    post '/v3/organizations', org_request_body.to_json, admin_headers
    expect(last_response).to have_status_code(201)
    parsed_response['guid']
  end

  def create_space(org_guid)
    space_request_body = {
      name: 'my-space',
      relationships: {
        organization: {
          data: {
            guid: org_guid
          }
        }
      }
    }

    post '/v3/spaces', space_request_body.to_json, admin_headers
    expect(last_response).to have_status_code(201)
    parsed_response['guid']
  end

  def get_route_service_plan(using:)
    get_service_plan_with(name: 'route_plan', using: using)
  end

  def get_service_plan_with(name:, using:)
    headers = using
    get "/v3/service_plans?names=#{name}", nil, headers
    expect(last_response).to have_status_code(200)

    parsed_response['resources'][0]['guid']
  end

  def make_plan_visible(plan_guid)
    post "v3/service_plans/#{plan_guid}/visibility", { type: 'public' }.to_json, admin_headers
    expect(last_response).to have_status_code(200)

    get "v3/service_plans/#{plan_guid}/visibility", nil, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['type']).to eq('public')
  end

  def create_service_instance(space_guid, plan_guid)
    create_service_instance_request_body = {
      name: 'my-service-instance',
      relationships: {
        service_plan: {
          data: {
            guid: plan_guid
          }
        },
        space: {
          data: {
            guid: space_guid
          }
        }
      },
      type: 'managed'
    }

    post '/v3/service_instances', create_service_instance_request_body.to_json, admin_headers
    expect(last_response).to have_status_code(202)
    last_response.headers['Location']
  end

  def wait_for_service_instance_to_be_created(space_guid, plan_guid)
    job_location = create_service_instance(space_guid, plan_guid)

    get job_location, nil, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['state']).to eql('PROCESSING')

    execute_all_jobs(expected_successes: 1, expected_failures: 0)

    get job_location, nil, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['state']).to eql('COMPLETE')

    get parsed_response['links']['service_instances']['href'], nil, admin_headers
    parsed_response['guid']
  end

  let(:create_service_broker_request_body) do
    {
      name: 'amazing-service-broker',
      url: 'http://example.org/amazing-service-broker',
      authentication: {
        type: 'basic',
        credentials: {
          username: 'admin',
          password: 'password',
        }
      },
      metadata: {
        labels: { to_update: 'value', to_delete: 'value', 'to.delete/with_prefix' => 'value' },
        annotations: { to_update: 'value', to_delete: 'value', 'to.delete/with_prefix' => 'value' }
      }
    }
  end

  let(:create_service_broker_request_body) do
    {
      name: 'amazing-service-broker',
      url: 'http://example.org/amazing-service-broker',
      authentication: {
        type: 'basic',
        credentials: {
          username: 'admin',
          password: 'password',
        }
      },
      metadata: {
        labels: { to_update: 'value', to_delete: 'value', 'to.delete/with_prefix' => 'value' },
        annotations: { to_update: 'value', to_delete: 'value', 'to.delete/with_prefix' => 'value' }
      }
    }
  end

  let(:catalog) do
    {
      'services' => [
        {
          'id' => 'catalog1',
          'name' => 'service_name-1',
          'description' => 'some description 1',
          'bindable' => true,
          'plans' => [
            {
              'id' => 'fake_plan_id-1',
              'name' => 'plan_name-1',
              'description' => 'fake_plan_description 1',
              'schemas' => nil
            }
          ]
        },
        {
          'id' => 'catalog2',
          'name' => 'route_volume_service_name-2',
          'requires' => ['volume_mount', 'route_forwarding'],
          'description' => 'some description 2',
          'bindable' => true,
          'bindings_retrievable' => true,
          'plans' => [
            {
              'id' => 'route_plan',
              'name' => 'route_plan',
              'description' => 'plan with route forwarding enabled',
              'schemas' => nil
            }
          ]
        },
      ]
    }.to_json
  end

  def create_route_binding_request(route_guid, service_instance_guid)
    {
      metadata: {
        annotations: {
          foo: 'bar'
        },
        labels: {
          baz: 'qux'
        }
      },
      relationships: {
        route: {
          data: {
            guid: route_guid
          }
        },
        service_instance: {
          data: {
            guid: service_instance_guid
          }
        }
      },
      parameters: {
        key1: 'value1',
        key2: 'value2'
      }
    }
  end

  def create_domain
    post '/v3/domains', { 'name': 'example.com', 'internal': false }.to_json, admin_headers
    expect(last_response).to have_status_code(201)
    parsed_response['guid']
  end

  def create_route(domain_guid, space_guid)
    route_request = {
      host: 'a-hostname',
      path: '/some_path',
      relationships: {
        domain: {
          data: { guid: domain_guid }
        },
        space: {
          data: { guid: space_guid }
        }
      }
    }
    post '/v3/routes', route_request.to_json, admin_headers
    expect(last_response).to have_status_code(201)
    parsed_response['guid']
  end
end
