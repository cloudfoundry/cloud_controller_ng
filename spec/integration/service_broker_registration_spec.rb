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

    broker_metadata = create_response.json_body.fetch('metadata')
    guid = broker_metadata.fetch('guid')
    expect(guid).to be
    expect(broker_metadata.fetch('url')).to eq("/v2/service_brokers/#{guid}")

    broker_entity = create_response.json_body.fetch('entity')
    expect(broker_entity.fetch('name')).to eq('BrokerDrug')
    expect(broker_entity.fetch('broker_url')).to eq('http://localhost:54329')
    expect(broker_entity).to_not have_key('token')

    new_body = JSON.dump(
      name: 'Updated Name'
    )

    update_response = make_put_request("/v2/service_brokers/#{guid}", new_body, authed_headers)
    expect(update_response.code.to_i).to eq(200)

    broker_metadata = update_response.json_body.fetch('metadata')
    expect(broker_metadata.fetch('guid')).to eq(guid)
    expect(broker_metadata.fetch('url')).to eq("/v2/service_brokers/#{guid}")

    broker_entity = update_response.json_body.fetch('entity')
    expect(broker_entity.fetch('name')).to eq('Updated Name')
    expect(broker_entity).to_not have_key('token')

    catalog_response = make_get_request('/v2/services?inline-relations-depth=1', authed_headers)
    expect(catalog_response.code.to_i).to eq(200)

    services = catalog_response.json_body.fetch('resources')
    service = services.first

    service_entity = service.fetch('entity')
    expect(service_entity.fetch('label')).to eq('custom-service')

    plans = service_entity.fetch('service_plans')
    plan = plans.first
    plan_entity = plan.fetch('entity')
    expect(plan_entity.fetch('name')).to eq('free')
  end
end
