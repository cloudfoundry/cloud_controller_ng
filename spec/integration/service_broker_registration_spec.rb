require "spec_helper"

describe "Service Broker Management", :type => :integration do
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

  specify "User registers and unregisters a service broker" do
    body = JSON.dump(
      broker_url: "http://localhost:54329",
      token: "supersecretshh",
      name: "BrokerDrug",
    )

    create_response = make_post_request("/v2/service_brokers", body, authed_headers)
    create_response.code.should == "201"
    guid = create_response.json_body["metadata"]["guid"]
    guid.should be
    create_response.json_body["metadata"]["url"].should == "/v2/service_brokers/#{guid}"
    create_response.json_body["entity"]["name"].should == "BrokerDrug"
    create_response.json_body["entity"]["broker_url"].should == "http://localhost:54329"
    create_response.json_body["entity"].should_not have_key("token")
  end
end
