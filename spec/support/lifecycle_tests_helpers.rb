module LifecycleSpecHelper
  BINDINGS_ENDPOINT = '/v3/service_credential_bindings/'.freeze

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

  def create_service_broker_request_body
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

  def create_service_broker
    post '/v3/service_brokers', create_service_broker_request_body.to_json, admin_headers
    expect(last_response).to have_status_code(202)
    execute_all_jobs(expected_successes: 1, expected_failures: 0)
  end

  def catalog
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

  def wait_for_resource_to_be_created(job_location, resource_type)
    get job_location, nil, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['state']).to eql('PROCESSING')

    execute_all_jobs(expected_successes: 1, expected_failures: 0)

    get job_location, nil, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['state']).to eql('COMPLETE')

    parsed_response['links'][resource_type]['href']
  end

  def wait_for_service_instance_to_be_created(space_guid, plan_guid)
    job_location = create_service_instance space_guid, plan_guid

    service_instance_location = wait_for_resource_to_be_created job_location, 'service_instances'

    get service_instance_location, nil, admin_headers
    parsed_response['guid']
  end

  def create_app_binding_request(service_instance_guid, app_guid)
    {
      type: 'app',
      metadata: {
        annotations: {
          foo: 'bar'
        },
        labels: {
          baz: 'qux'
        }
      },
      relationships: {
        app: {
          data: {
            guid: app_guid
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

  def create_key_binding_request(service_instance_guid)
    {
      type: 'key',
      name: 'my-service-key',
      metadata: {
        annotations: {
          foo: 'bar'
        },
        labels: {
          baz: 'qux'
        }
      },
      relationships: {
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

  def get_route_service_plan(using:)
    get_service_plan_with(name: 'route_plan', using: using)
  end

  def get_service_plan_with(name:, using:)
    headers = using
    get "/v3/service_plans?names=#{name}", nil, headers
    expect(last_response).to have_status_code(200)

    parsed_response['resources'][0]['guid']
  end

  def push_app(space_guid)
    VCAP::CloudController::AppModel.make(name: 'my-app', space_guid: space_guid).guid
  end

  def create_binding(request)
    post BINDINGS_ENDPOINT, request.to_json, admin_headers
    expect(last_response).to have_status_code(202)
    wait_for_resource_to_be_created(last_response.headers['Location'], 'service_credential_binding')
  end
end
