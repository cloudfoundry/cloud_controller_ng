require "spec_helper"

describe "Service Broker Management", :type => :integration do
  before(:all) do
    start_nats
    start_cc
  end

  after(:all) do
    stop_cc
    stop_nats
  end

  let(:authed_headers) do
    {
      "Authorization" => "bearer #{admin_token}",
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end

  specify "User registers and unregisters a service broker" do
    body = JSON.dump(
      broker_url: "http://example.com/",
      token: "supersecretshh",
      name: "BrokerDrug",
    )

    create_response = make_post_request("/v2/service_brokers", body, authed_headers)
    create_response.code.should == "201"
    guid = create_response.json_body["metadata"]["guid"]
    guid.should be
    create_response.json_body["metadata"]["url"].should == "/v2/service_brokers/#{guid}"
    create_response.json_body["entity"]["name"].should == "BrokerDrug"
    create_response.json_body["entity"]["broker_url"].should == "http://example.com/"
    create_response.json_body["entity"].should_not have_key("token")
  end
end
