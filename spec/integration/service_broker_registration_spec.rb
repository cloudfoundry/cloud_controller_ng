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

  specify "User registers and re-registers a service broker" do
    body = JSON.dump(
      broker_url: "http://localhost:54329",
      token: "supersecretshh",
      name: "BrokerDrug",
    )

    create_response = make_post_request('/v2/service_brokers', body, authed_headers)
    expect(create_response.code.to_i).to eq(201)

    metadata = create_response.json_body.fetch('metadata')
    guid = metadata.fetch('guid')
    expect(guid).to be
    expect(metadata.fetch('url')).to eq("/v2/service_brokers/#{guid}")

    entity = create_response.json_body.fetch('entity')
    expect(entity.fetch('name')).to eq('BrokerDrug')
    expect(entity.fetch('broker_url')).to eq('http://localhost:54329')
    expect(entity).to_not have_key('token')

    new_body = JSON.dump(
      name: 'Updated Name'
    )

    update_response = make_put_request("/v2/service_brokers/#{guid}", new_body, authed_headers)
    expect(update_response.code.to_i).to eq(200)

    metadata = update_response.json_body.fetch('metadata')
    expect(metadata.fetch('guid')).to eq(guid)
    expect(metadata.fetch('url')).to eq("/v2/service_brokers/#{guid}")

    entity = update_response.json_body.fetch('entity')
    expect(entity.fetch('name')).to eq('Updated Name')
    expect(entity).to_not have_key('token')
  end
end
