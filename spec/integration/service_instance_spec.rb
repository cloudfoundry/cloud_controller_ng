require "spec_helper"

describe "Service Instance Management", :type => :integration do
  def start_fake_service_broker
    fake_service_broker_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'support', 'integration', 'fake_service_broker.rb'))
    @fake_service_broker_pid = run_cmd("ruby #{fake_service_broker_path}")
  end

  def stop_fake_service_broker
    Process.kill("KILL", @fake_service_broker_pid)
  end

  before(:all) do
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
    make_post_request(
      "/v2/organizations",
      { "name" => "foo_org-#{SecureRandom.uuid}" }.to_json,
      authed_headers
    )
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

  specify "User creates an instance of a v2 service" do
    body = JSON.dump(
      broker_url: "http://localhost:54329",
      token: "supersecretshh",
      name: "BrokerDrug",
    )

    create_broker_response = make_post_request('/v2/service_brokers', body, authed_headers)
    expect(create_broker_response.code.to_i).to eq(201)

    service_plan_response = make_get_request('/v2/service_plans', authed_headers)
    expect(service_plan_response.code.to_i).to eq(200)

    expect(service_plan_response.json_body.fetch('total_results')).to be > 0
    service_guid = service_plan_response.json_body.fetch('resources').first.fetch('metadata').fetch('guid')

    body = JSON.dump(
      name: 'my-v2-service',
      service_plan_guid: service_guid,
      space_guid: space_guid
    )

    create_response = make_post_request('/v2/service_instances', body, authed_headers)
    expect(create_response.code.to_i).to eq(201)
  end
end
