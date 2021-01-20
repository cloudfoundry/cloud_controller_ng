require 'spec_helper'
require 'cloud_controller'

# This lifecycle test aims to use different v3 service endpoints together
RSpec.describe 'V3 service credential bindings synoptic' do
  before do
    stub_request(:get, 'http://example.org/amazing-service-broker/v2/catalog').
      with(basic_auth: %w(admin password)).
      to_return(status: 200, body: catalog, headers: {})

    stub_request(:put, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 201, body: {}.to_json, headers: {})

    stub_request(:get, 'https://main.default.svc.cluster-domain.example/apis/networking.cloudfoundry.org/v1alpha1').
      with(basic_auth: %w(admin password)).
      to_return(status: 200, body: '', headers: {})

    stub_request(:get, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+/service_bindings/.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 200, body: { parameters: { key1: 'value1', key2: 'value2' } }.to_json, headers: {})

    stub_request(:put, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+/service_bindings/.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 201, body: {}.to_json, headers: {})

    stub_request(:delete, %r{\Ahttp://example.org/amazing-service-broker/v2/service_instances/.+/service_bindings/.+\z}).
      with(basic_auth: %w(admin password)).
      to_return(status: 410, body: '', headers: {})
    VCAP::CloudController::Config.config.set(:kubernetes, nil)

    stub_request(:post, 'https://uaa.service.cf.internal/oauth/token').
      with(body: 'grant_type=client_credentials').
      to_return(status: 200, body: "{ token_type: 'Bearer', access_token: 'dXNlcm5hbWVfbG9va3VwX2NsaWVudF9uYW1lOnVzZXJuYW1lX2xvb2t1cF9zZWNyZXQ=' }", headers: {})
  end

  it 'works end to end' do
    org_guid = create_org
    space_guid = create_space org_guid

    create_service_broker

    plan_guid = get_route_service_plan using: admin_headers
    make_plan_visible plan_guid

    service_instance_guid = wait_for_service_instance_to_be_created(space_guid, plan_guid)

    app_guid = push_app space_guid

    create_request = create_app_binding_request(service_instance_guid, app_guid)
    post LifecycleSpecHelper::BINDINGS_ENDPOINT, create_request.to_json, admin_headers
    expect(last_response).to have_status_code(202)
    execute_all_jobs(expected_successes: 1, expected_failures: 0)

    create_request = create_key_binding_request service_instance_guid
    post LifecycleSpecHelper::BINDINGS_ENDPOINT, create_request.to_json, admin_headers
    expect(last_response).to have_status_code(202)
    execute_all_jobs(expected_successes: 1, expected_failures: 0)

    get LifecycleSpecHelper::BINDINGS_ENDPOINT, nil, admin_headers
    expect(parsed_response['resources']).to have(2).items
    app_binding_guid = parsed_response['resources'].select { |r| r['type'] == 'app' }[0]['guid']
    key_binding_guid = parsed_response['resources'].select { |r| r['type'] == 'key' }[0]['guid']

    can_query_parameters(app_binding_guid, create_request)
    can_query_parameters(key_binding_guid, create_request)

    updates_metadata(app_binding_guid, create_request)
    updates_metadata(key_binding_guid, create_request)

    deletes_binding app_binding_guid
    deletes_binding key_binding_guid
  end

  def can_query_parameters(binding_guid, create_request)
    get "#{LifecycleSpecHelper::BINDINGS_ENDPOINT}#{binding_guid}/parameters", nil, admin_headers
    expect(parsed_response).to contain_exactly(*create_request[:parameters].with_indifferent_access)
  end

  def updates_metadata(binding_guid, create_request)
    update_request = {
      metadata: {
        labels: { key: 'value' },
        annotations: { note: 'detailed information' }
      }
    }
    patch "#{LifecycleSpecHelper::BINDINGS_ENDPOINT}#{binding_guid}", update_request.to_json, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['metadata']['annotations']).to contain_exactly(*update_request[:metadata][:annotations].merge(create_request[:metadata][:annotations]).stringify_keys)
    expect(parsed_response['metadata']['labels']).to contain_exactly(*update_request[:metadata][:labels].merge(create_request[:metadata][:labels]).stringify_keys)
  end

  def deletes_binding(binding_guid)
    delete "#{LifecycleSpecHelper::BINDINGS_ENDPOINT}#{binding_guid}", nil, admin_headers
    expect(last_response).to have_status_code(202)
    execute_all_jobs(expected_successes: 1, expected_failures: 0)
    get "#{LifecycleSpecHelper::BINDINGS_ENDPOINT}#{binding_guid}", nil, admin_headers
    expect(last_response).to have_status_code(404)
  end
end
