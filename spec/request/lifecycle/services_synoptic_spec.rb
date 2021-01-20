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

    stub_request(:delete, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 200, body: {}.to_json, headers: {})

    stub_request(:post, 'https://uaa.service.cf.internal/oauth/token').
      with(body: 'grant_type=client_credentials').
      to_return(status: 200, body: "{ token_type: 'Bearer', access_token: 'dXNlcm5hbWVfbG9va3VwX2NsaWVudF9uYW1lOnVzZXJuYW1lX2xvb2t1cF9zZWNyZXQ=' }", headers: {})

    stub_request(:put, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+/service_bindings/.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 201, body: {}.to_json, headers: {})

    stub_request(:delete, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+/service_bindings/.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 202, body: {}.to_json, headers: {})

    stub_request(:get, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+/service_bindings/.+/last_operation.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 410, body: {}.to_json, headers: {})
  end

  it 'works end to end' do
    org_guid = create_org
    space_guid = create_space org_guid

    app_guid = push_app space_guid

    create_service_broker

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
      'name' => 'route_plan'
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
      wait_for_resource_to_be_created(job_location, 'service_instances')

    get service_instance_location, nil, admin_headers
    expect(last_response).to have_status_code(200)

    service_instances = get_all_service_instances
    expect(service_instances[0]).to include(
      'name' => 'my-service-instance'
    )

    service_instance_guid = service_instances[0]['guid']

    create_binding(create_app_binding_request(service_instance_guid, app_guid))
    create_binding(create_key_binding_request(service_instance_guid))

    wait_for_service_instance_to_be_deleted(service_instance_location)

    get service_instance_location, nil, admin_headers
    expect(last_response).to have_status_code(404)

    get LifecycleSpecHelper::BINDINGS_ENDPOINT, nil, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['resources']).to be_empty
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

  def wait_for_service_instance_to_be_deleted(service_instance_location)
    delete service_instance_location, nil, admin_headers
    expect(last_response).to have_status_code(202)
    job_location = last_response.headers['Location']

    get job_location, nil, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['state']).to eql('PROCESSING')

    execute_all_jobs(expected_successes: 2, expected_failures: 1)

    get job_location, nil, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['state']).to eql('FAILED')
    expect(parsed_response['errors'][0]['detail']).to include('An operation for the service binding')

    delete service_instance_location, nil, admin_headers
    expect(last_response).to have_status_code(202)

    execute_all_jobs(expected_successes: 1, expected_failures: 0)
  end

  def get_all_service_instances
    get '/v3/service_instances', nil, admin_headers
    expect(last_response).to have_status_code(200)
    parsed_response['resources']
  end

  let(:empty_headers) do
    {}
  end
end
# rubocop:enable Naming/AccessorMethodName
