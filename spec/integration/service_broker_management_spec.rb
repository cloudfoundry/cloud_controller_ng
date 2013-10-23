require "spec_helper"

describe "Service Broker Management", type: :integration do
  def start_fake_service_broker
    fake_service_broker_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'support', 'integration', 'fake_service_broker.rb'))
    @fake_service_broker_pid = run_cmd("ruby #{fake_service_broker_path}")
  end

  def stop_fake_service_broker
    Process.kill("KILL", @fake_service_broker_pid)
  end

  before do
    start_fake_service_broker
    start_nats
    start_cc
  end

  after do
    stop_cc
    stop_nats
    stop_fake_service_broker
  end

  let(:admin_headers) do
    {
      "Authorization" => "bearer #{admin_token}",
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end
  let(:user_headers) do
    {
      "Authorization" => "bearer #{user_token}",
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end

  let(:org) do
    make_post_request(
      "/v2/organizations",
      { "name" => "foo_org-#{SecureRandom.uuid}", "billing_enabled" => true }.to_json,
      admin_headers
    )
  end

  let(:org_guid) { org.json_body.fetch("metadata").fetch("guid") }

  let(:space) do
    make_post_request(
      "/v2/spaces",
      { "name" => "foo_space",
        "organization_guid" => org_guid }.to_json,
      admin_headers
    )
  end

  let(:space_guid) { space.json_body.fetch("metadata").fetch("guid") }

  specify "Admin registers and re-registers a service broker" do
    body = JSON.dump(
      broker_url: "http://localhost:54329",
      auth_username: "me",
      auth_password: "supersecretshh",
      name: "BrokerDrug",
    )

    create_response = make_post_request('/v2/service_brokers', body, admin_headers)
    expect(create_response.code.to_i).to eq(201)

    broker_metadata = create_response.json_body.fetch('metadata')
    guid = broker_metadata.fetch('guid')
    expect(guid).to be
    expect(broker_metadata.fetch('url')).to eq("/v2/service_brokers/#{guid}")

    broker_entity = create_response.json_body.fetch('entity')
    expect(broker_entity.fetch('name')).to eq('BrokerDrug')
    expect(broker_entity.fetch('broker_url')).to eq('http://localhost:54329')
    expect(broker_entity.fetch('auth_username')).to eq('me')
    expect(broker_entity).to_not have_key('auth_password')

    new_body = JSON.dump(
      name: 'Updated Name'
    )

    update_response = make_put_request("/v2/service_brokers/#{guid}", new_body, admin_headers)
    expect(update_response.code.to_i).to eq(200)

    broker_metadata = update_response.json_body.fetch('metadata')
    expect(broker_metadata.fetch('guid')).to eq(guid)
    expect(broker_metadata.fetch('url')).to eq("/v2/service_brokers/#{guid}")

    broker_entity = update_response.json_body.fetch('entity')
    expect(broker_entity.fetch('name')).to eq('Updated Name')
    expect(broker_entity.fetch('auth_username')).to eq('me')
    expect(broker_entity).to_not have_key('auth_password')

    catalog_response = make_get_request('/v2/services?inline-relations-depth=1', admin_headers)
    expect(catalog_response.code.to_i).to eq(200)

    services = catalog_response.json_body.fetch('resources')
    service = services.first

    service_entity = service.fetch('entity')
    expect(service_entity.fetch('label')).to eq('custom-service')
    expect(service_entity.fetch('bindable')).to eq(true)
    expect(service_entity.fetch('tags')).to match_array(['mysql', 'relational'])

    plans = service_entity.fetch('service_plans')
    expect(plans.length).to eq(2)
  end

  describe 'removing a service broker' do
    specify "Admin adds and removes a service broker" do
      body = JSON.dump(
        broker_url: "http://localhost:54329",
        auth_username: "me",
        auth_password: "supersecretshh",
        name: "BrokerDrug",
      )

      # create it
      create_response = make_post_request('/v2/service_brokers', body, admin_headers)
      expect(create_response.code.to_i).to eq(201)
      broker_metadata = create_response.json_body.fetch('metadata')
      guid = broker_metadata.fetch('guid')

      # delete it
      delete_response = make_delete_request("/v2/service_brokers/#{guid}", admin_headers)
      expect(delete_response.code.to_i).to eq(204)

      # make sure its services are no longer available
      catalog_response = make_get_request('/v2/services?inline-relations-depth=1', admin_headers)
      expect(catalog_response.code.to_i).to eq(200)

      services = catalog_response.json_body.fetch('resources')
      services.each do |service|
        service_entity = service.fetch('entity')
        expect(service_entity.fetch('label')).to_not eq('custom-service')
      end
    end

    context 'when a service instance exists' do
      let(:org) do
        make_post_request(
          "/v2/organizations",
          { "name" => "foo_org-#{SecureRandom.uuid}" }.to_json,
          admin_headers
        )
      end

      let(:org_guid) { org.json_body.fetch("metadata").fetch("guid") }

      let(:space) do
        make_post_request(
          "/v2/spaces",
          { "name" => "foo_space",
            "organization_guid" => org_guid }.to_json,
          admin_headers
        )
      end

      let(:space_guid) { space.json_body.fetch("metadata").fetch("guid") }

      it 'does not allow service broker to be removed' do
        body = JSON.dump(
          broker_url: "http://localhost:54329",
          auth_username: "me",
          auth_password: "supersecretshh",
          name: "BrokerDrug",
        )

        # create it
        create_response = make_post_request('/v2/service_brokers', body, admin_headers)
        broker_metadata = create_response.json_body.fetch('metadata')
        guid = broker_metadata.fetch('guid')

        service_plan_response = make_get_request('/v2/service_plans', admin_headers)
        service_guid = service_plan_response.json_body.fetch('resources').first.fetch('metadata').fetch('guid')

        # create a service instance
        body = JSON.dump(
          name: 'my-v2-service',
          service_plan_guid: service_guid,
          space_guid: space_guid
        )
        create_response = make_post_request('/v2/service_instances', body, admin_headers)
        expect(create_response.code.to_i).to eq(201)

        # try to delete it
        delete_response = make_delete_request("/v2/service_brokers/#{guid}", admin_headers)
        expect(delete_response.code.to_i).to eq(400)

        # make sure the services are still available
        catalog_response = make_get_request('/v2/services?inline-relations-depth=1', admin_headers)
        expect(catalog_response.code.to_i).to eq(200)

        services = catalog_response.json_body.fetch('resources')
        service = services.first

        service_entity = service.fetch('entity')
        expect(service_entity.fetch('label')).to eq('custom-service')

        plans = service_entity.fetch('service_plans')
        expect(plans.length).to eq(2)
      end
    end
  end

  specify "An existing service plan disappears from the catalog" do
    # Add the broker
    body = JSON.dump(
      broker_url: "http://localhost:54329",
      auth_username: "me",
      auth_password: "supersecretshh",
      name: "BrokerDrug",
    )

    create_response = make_post_request('/v2/service_brokers', body, admin_headers)
    expect(create_response.code.to_i).to eq(201)
    broker_guid = create_response.json_body.fetch('metadata').fetch('guid')

    # create a service instance of first plan
    service_instance_guid = create_service_instance

    # verify that we have two plans
    plans = get_plans
    expect(plans.length).to eq(2)

    # remove the second plan from fake
    delete_last_plan_from_broker

    # update the service broker
    update_service_broker(broker_guid)

    # verify that second plan is inactive
    plans = get_plans
    expect(plans.length).to eq(1)

    # remove the first plan from fake
    delete_last_plan_from_broker

    # update the service broker
    update_service_broker(broker_guid)

    # verify that no services are visible
    services = get_services
    expect(services).to be_empty

    # verify that the plan still exists in the db but is inactive
    plans = get_plans(admin_headers)
    expect(plans.length).to eq(1)

    # delete instance
    delete_service_instance(service_instance_guid)

    # update the service broker
    update_service_broker(broker_guid)

    # verify that the plan has been removed from the db
    plans = get_plans(admin_headers)
    expect(plans.length).to eq(0)
  end

  def service_guid
    service_plan_response = make_get_request('/v2/service_plans', admin_headers)
    expect(service_plan_response.code.to_i).to eq(200)

    expect(service_plan_response.json_body.fetch('total_results')).to be > 0
    service_plan_response.json_body.fetch('resources').first.fetch('metadata').fetch('guid')
  end

  def create_service_instance
    body = JSON.dump(
      name: 'my-v2-service',
      service_plan_guid: service_guid,
      space_guid: space_guid
    )
    create_response = make_post_request('/v2/service_instances', body, admin_headers)
    expect(create_response.code.to_i).to eq(201)

    create_response.json_body.fetch('metadata').fetch('guid')
  end

  def delete_service_instance(instance_guid)
    delete_response = make_delete_request("/v2/service_instances/#{instance_guid}", admin_headers)
    expect(delete_response.code.to_i).to eq(204), "Delete request failed with #{delete_response.code}, #{delete_response.body.inspect}"
  end

  def update_service_broker(broker_guid)
    update_response = make_put_request("/v2/service_brokers/#{broker_guid}", {}.to_json, admin_headers)
    expect(update_response.code.to_i).to eq(200)
  end

  def get_services(headers=user_headers)
    catalog_response = make_get_request('/v2/services?inline-relations-depth=1', headers)
    expect(catalog_response.code.to_i).to eq(200)

    catalog_response.json_body.fetch('resources')
  end

  def get_plans(headers=user_headers)
    services = get_services(headers)
    service = services.first
    service_entity = service.fetch('entity')
    service_entity.fetch('service_plans')
  end

  def delete_last_plan_from_broker
    http = Net::HTTP.new('localhost', 54329)
    request = Net::HTTP::Delete.new('/plan/last')
    request.basic_auth('admin', 'supersecretshh')
    response = http.request(request)
    expect(response.code.to_i).to eq(204)
  end

  def user_token
    token = {
      "aud" => "cloud_controller",
      "exp" => Time.now.to_i + 10_000,
      "client_id" => Sham.guid,
      "scope" => [],
    }
    CF::UAA::TokenCoder.encode(token, :skey => "tokensecret", :algorithm => "HS256")
  end
end
