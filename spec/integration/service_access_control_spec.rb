require "spec_helper"
require "securerandom"

describe "Service access control", :type => :integration do
  before do
    start_nats
    start_cc
  end

  after do
    stop_cc
    stop_nats
  end

  let(:admin_headers) {
    {
      "Authorization" => "bearer #{admin_token}",
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  }

  def user_header(user_guid)
    token_config = {
      "aud" => "cloud_controller",
      "exp" => Time.now.to_i + 10_000,
      "user_id" => user_guid,
      "scope" => [],
    }
    user_token =  CF::UAA::TokenCoder.encode(token_config, :skey => "tokensecret", :algorithm => "HS256")
    {
      "Authorization" => "bearer #{user_token}",
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end

  def create_service
    service_response = make_post_request('/v2/services',
      {
        label: "service_#{SecureRandom.uuid}",
        provider: "provider",
        url: "http://example.com",
        description: "Test service for checking authenticated plans",
        version: "1.0",
        info_url: "http://example.com",
      }.to_json,
      admin_headers)
    service_response.json_body["metadata"]["guid"]
  end

  def create_plan(service_guid)
    plan_response = make_post_request('/v2/service_plans',
      {
        name: "service_plan_test",
        description: "Test plan",
        free: true,
        service_guid: service_guid,
        unique_id: SecureRandom.uuid,
      }.to_json,
      admin_headers)
    plan_response.json_body["metadata"]["guid"]
  end

  def create_org
    org_response = make_post_request('/v2/organizations',
      {name: "org_#{SecureRandom.uuid}",}.to_json, admin_headers)
    org_response.json_body["metadata"]["guid"]
  end

  def create_user(org_guid)
    user_guid = SecureRandom.uuid
    user_response = make_post_request('/v2/users',
      {
        guid: user_guid,
        organization_guids: [org_guid],
      }.to_json,
      admin_headers)
    user_guid
  end

  def visible_plan_guids(user_guid)
    plan_response = make_get_request('/v2/service_plans', user_header(user_guid)).json_body
    visible_plan_guids = plan_response.fetch('resources').map do |r|
      r.fetch('metadata').fetch('guid')
    end
  end

  it "ensures that new plans are private" do
    service_guid = create_service
    plan_guid = create_plan(service_guid)

    org_guid = create_org
    user_guid = create_user(org_guid)

    visible_plan_guids(user_guid).should_not include(plan_guid)
  end
end
