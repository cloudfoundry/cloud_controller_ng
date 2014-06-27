require "spec_helper"

describe "Service Instance Management", type: :integration do
  before(:all) do
    at_exit { stop_fake_service_broker }
    start_fake_service_broker
    start_nats
    start_cc
  end

  after(:all) do
    stop_cc
    stop_nats
    stop_fake_service_broker
  end

  let(:authed_headers) do
    {
      "Authorization" => "bearer #{admin_token}",
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end

  let(:org) do
    org_with_default_quota(authed_headers)
  end

  let(:org_guid) { org.json_body.fetch("metadata").fetch("guid") }

  let(:space) do
    make_post_request(
      "/v2/spaces",
      { "name" => "foo_space",
        "organization_guid" => org_guid }.to_json,
      authed_headers
    )
  end

  let(:space_guid) { space.json_body.fetch("metadata").fetch("guid") }

  let(:syslog_drain_url) { 'syslog://example.com:514' }

  let(:syslog_drain_url2) { 'syslog://example2.com:514' }

  specify "User creates an instance of a v2 service" do
    register_service_broker
    create_service_instance
    create_application
    bind_managed_service_instance
    unbind_service_instance
    delete_service_instance
  end

  specify "User creates an instance of a user-provided service" do
    create_user_provided_service_instance
    create_application
    bind_user_provided_service_instance
  end

  specify "User updates an instance of a user-provided service" do
    create_user_provided_service_instance
    create_application
    bind_user_provided_service_instance
    update_user_provided_service_instance
    unbind_service_instance
    bind_user_provided_service_instance
    verify_updated_service_binding
  end

  def counts_from_fake_service_broker
    http = Net::HTTP.new('localhost', 54329)
    request = Net::HTTP::Get.new('/counts')
    request.basic_auth('admin', 'supersecretshh')
    response = http.request(request)
    JSON.parse(response.body)
  end

  def delete_service_instance
    delete_response = make_delete_request("/v2/service_instances/#{@service_instance_guid}", authed_headers)
    expect(delete_response.code.to_i).to eq(204), "Delete request failed with #{delete_response.code}, #{delete_response.body.inspect}"

    expect(counts_from_fake_service_broker.fetch('instances')).to eq(0)
  end

  def unbind_service_instance
    unbind_response = make_delete_request("/v2/service_bindings/#{@binding_guid}", authed_headers)
    expect(unbind_response.code.to_i).to eq(204), "Unbind request failed with #{unbind_response.code}, #{unbind_response.body.inspect}"

    expect(counts_from_fake_service_broker.fetch('bindings')).to eq(0)
  end

  def bind_service_instance
    body = JSON.dump(
      service_instance_guid: @service_instance_guid,
      app_guid: @application_guid
    )

    bind_response = make_post_request('/v2/service_bindings', body, authed_headers)
    expect(bind_response.code.to_i).to eq(201), "Bind request failed with #{bind_response.code}, #{bind_response.body.inspect}"
    @binding_guid = bind_response.json_body.fetch('metadata').fetch('guid')
    bind_response
  end

  def bind_user_provided_service_instance
    bind_response = bind_service_instance
    expect(bind_response.json_body.fetch('entity').fetch('syslog_drain_url')).to eq @syslog_drain_url
  end

  def bind_managed_service_instance
    bind_service_instance
    expect(counts_from_fake_service_broker.fetch('bindings')).to eq(1)
  end

  def verify_updated_service_binding
    bind_response = make_get_request("/v2/user_provided_service_instances/#{@service_instance_guid}/service_bindings", authed_headers)
    expect(bind_response.json_body.fetch('resources').first.fetch('entity').fetch('syslog_drain_url')).to eq (syslog_drain_url2)
  end

  def register_service_broker
    body = JSON.dump(
      broker_url: "http://localhost:54329",
      auth_username: "cc",
      auth_password: "supersecretshh",
      name: "BrokerDrug",
    )

    create_broker_response = make_post_request('/v2/service_brokers', body, authed_headers)
    expect(create_broker_response.code.to_i).to eq(201)

    update_response = make_put_request("/v2/service_plans/#{service_plan_guid}", JSON.dump(public: true), authed_headers)
    expect(update_response.code.to_i).to eq(201)
  end

  def create_service_instance
    body = JSON.dump(
      name: 'my-v2-service',
      service_plan_guid: service_plan_guid,
      space_guid: space_guid
    )
    create_response = make_post_request('/v2/service_instances', body, authed_headers)
    expect(create_response.code.to_i).to eq(201)
    @service_instance_guid = create_response.json_body.fetch('metadata').fetch('guid')

    expect(counts_from_fake_service_broker.fetch('instances')).to eq(1)
  end

  def create_user_provided_service_instance
    body = JSON.dump(
      name: 'my-v2-user-provided-service',
      space_guid: space_guid,
      syslog_drain_url: syslog_drain_url
    )
    @syslog_drain_url = syslog_drain_url
    create_response = make_post_request('/v2/user_provided_service_instances', body, authed_headers)
    expect(create_response.code.to_i).to eq(201)
    @service_instance_guid = create_response.json_body.fetch('metadata').fetch('guid')
  end

  def update_user_provided_service_instance
    body = JSON.dump(
      name: 'my-v2-user-provided-service',
      space_guid: space_guid,
      syslog_drain_url: syslog_drain_url2
    )
    @syslog_drain_url = syslog_drain_url2
    create_response = make_put_request("/v2/user_provided_service_instances/#{@service_instance_guid}", body, authed_headers)
    expect(create_response.code.to_i).to eq(201)
  end

  def service_plan_guid
    service_plan_response = make_get_request('/v2/service_plans', authed_headers)
    expect(service_plan_response.code.to_i).to eq(200)

    expect(service_plan_response.json_body.fetch('total_results')).to be > 0
    service_plan_response.json_body.fetch('resources').first.fetch('metadata').fetch('guid')
  end

  def create_application
    create_app_response = make_post_request(
      "/v2/apps",
      {
        "name" => "test-app",
        "space_guid" => space_guid
      }.to_json,
      authed_headers
    )
    expect(create_app_response.code.to_i).to eq(201)
    @application_guid = create_app_response.json_body.fetch('metadata').fetch('guid')
  end

end
