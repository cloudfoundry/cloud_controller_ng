require 'spec_helper'
require 'request_spec_shared_examples'
require 'cloud_controller'
require 'services'
require 'messages/service_broker_update_message'

# This lifecycle test aims to use different v3 service endpoints together
# rubocop:disable Naming/AccessorMethodName
RSpec.describe 'V3 services synoptic' do
  before do
    stub_request(:get, 'http://example.org/amazing-service-broker/v2/catalog').
      with(basic_auth: %w(admin password)).
      to_return(status: 200, body: catalog, headers: {})

    stub_request(:put, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 201, body: {}.to_json, headers: {})

    stub_request(:post, 'https://uaa.service.cf.internal/oauth/token').
      with(body: 'grant_type=client_credentials').
      to_return(status: 200, body: "{ token_type: 'Bearer', access_token: 'dXNlcm5hbWVfbG9va3VwX2NsaWVudF9uYW1lOnVzZXJuYW1lX2xvb2t1cF9zZWNyZXQ=' }", headers: {})
  end

  it 'works end to end' do
    org_guid = create_org
    space_guid = create_space(org_guid)

    post '/v3/service_brokers', create_service_broker_request_body.to_json, admin_headers
    expect(last_response).to have_status_code(202)
    execute_all_jobs(expected_successes: 1, expected_failures: 0)

    service_offerings = get_service_offerings
    expect(service_offerings[0]).to include(
      'name' => 'service_name-1'
    )
    expect(service_offerings[1]).to include(
      'name' => 'route_volume_service_name-2'
    )

    plans = get_service_plans using: admin_headers
    expect(plans[0]).to include(
      'name' => 'plan_name-1'
    )
    expect(plans[1]).to include(
      'name' => 'plan_name-2'
    )
    plan_guid = plans[0]['guid']

    expect(
      get_service_plans(using: empty_headers)
    ).to have(0).elements

    make_plan_visible plan_guid

    expect(
      get_service_plans(using: empty_headers)
    ).to have(1).elements

    job_location = create_service_instance(space_guid, plan_guid)

    service_instance_location =
      wait_for_service_instance_to_be_created(job_location)

    get service_instance_location, nil, admin_headers
    expect(last_response).to have_status_code(200)

    service_instances = get_all_service_instances
    expect(service_instances[0]).to include(
      'name' => service_instance_name
    )

    # TODO: bind a service instance once those endpoints are written
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

  def get_service_offerings
    get '/v3/service_offerings', nil, admin_headers
    expect(last_response).to have_status_code(200)
    parsed_response['resources']
  end

  def get_service_plans(using:)
    headers = using
    get '/v3/service_plans', nil, headers
    expect(last_response).to have_status_code(200)

    parsed_response['resources']
  end

  def make_plan_visible(plan_guid)
    post "v3/service_plans/#{plan_guid}/visibility", visibility_request.to_json, admin_headers
    expect(last_response).to have_status_code(200)

    get "v3/service_plans/#{plan_guid}/visibility", nil, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['type']).to eq('public')
  end

  def create_service_instance(space_guid, plan_guid)
    create_service_instance_request_body = {
      name: service_instance_name,
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

  def wait_for_service_instance_to_be_created(job_location)
    get job_location, nil, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['state']).to eql('PROCESSING')

    execute_all_jobs(expected_successes: 1, expected_failures: 0)

    get job_location, nil, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['state']).to eql('COMPLETE')

    parsed_response['links']['service_instances']['href']
  end

  def get_all_service_instances
    get '/v3/service_instances', nil, admin_headers
    expect(last_response).to have_status_code(200)
    parsed_response['resources']
  end

  let(:service_instance_name) { 'my-service-instance' }

  let(:visibility_request) do
    {
        type: 'public'
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

  let(:empty_headers) do
    {}
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
              'plans' => [
                {
                    'id' => 'fake_plan_id-2',
                    'name' => 'plan_name-2',
                    'description' => 'fake_plan_description 2',
                    'schemas' => nil
                }
              ]
          },
        ]
    }.to_json
  end
end
# rubocop:enable Naming/AccessorMethodName
