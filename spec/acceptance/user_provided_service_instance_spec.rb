require 'spec_helper'

RSpec.describe 'User Provided Service Instance' do
  include VCAP::CloudController::BrokerApiHelper

  before(:each) do
    setup_cc
    create_app
  end

  let(:syslog_drain_url) { 'syslog://example.com:514' }
  let(:syslog_drain_url2) { 'syslog://example2.com:514' }

  it 'can be created, bound, unbound, updated' do
    # create
    post('/v2/user_provided_service_instances', {
      name:             'my-v2-user-provided-service',
      space_guid:       @space_guid,
      syslog_drain_url: syslog_drain_url
    }.to_json, json_headers(admin_headers))
    expect(last_response.status).to eq(201)
    json_body             = JSON.parse(last_response.body)
    service_instance_guid = json_body.fetch('metadata').fetch('guid')

    # bind
    post('/v2/service_bindings', {
      service_instance_guid: service_instance_guid,
      app_guid:              @app_guid
    }.to_json, json_headers(admin_headers))
    expect(last_response.status).to eq(201)
    json_body    = JSON.parse(last_response.body)
    binding_guid = json_body.fetch('metadata').fetch('guid')
    expect(json_body.fetch('entity').fetch('syslog_drain_url')).to eq(syslog_drain_url)

    # unbind
    delete("/v2/service_bindings/#{binding_guid}", nil, json_headers(admin_headers))
    expect(last_response.status).to eq(204)

    # update service instance
    put("/v2/user_provided_service_instances/#{service_instance_guid}", {
      name:             'my-v2-user-provided-service',
      space_guid:       @space_guid,
      syslog_drain_url: syslog_drain_url2
    }.to_json, json_headers(admin_headers))
    expect(last_response.status).to eq(201)

    # rebind after update
    post('/v2/service_bindings', {
      service_instance_guid: service_instance_guid,
      app_guid:              @app_guid
    }.to_json, json_headers(admin_headers))
    expect(last_response.status).to eq(201)
    json_body = JSON.parse(last_response.body)
    expect(json_body.fetch('entity').fetch('syslog_drain_url')).to eq(syslog_drain_url2)
  end
end
