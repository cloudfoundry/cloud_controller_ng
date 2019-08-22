require 'spec_helper'
require 'cloud_controller'
require 'services'

RSpec.describe 'V3 service brokers' do
  let(:global_broker_id) { 'global-service-id' }
  let(:space_broker_id) { 'space-service-id' }

  def catalog(id=global_broker_id)
    {
      'services' => [
        {
          'id' => "#{id}-1",
          'name' => 'service_name-1',
          'description' => 'some description 1',
          'bindable' => true,
          'plans' => [
            {
                'id' => 'fake_plan_id-1',
                'name' => 'plan_name-1',
                'description' => 'fake_plan_description 1',
                'schemas' => nil
            }
          ],
          'dashboard_client' => dashboard_client(id)
        },
        {
          'id' => "#{id}-2",
          'name' => 'route_volume_service_name-2',
          'requires' => ['volume_mount', 'route_forwarding'],
          'description' => 'some description 2',
          'bindable' => true,
          'plans' => [
            {
                'id' => 'fake_plan_id-2',
                'name' => 'plan_name-2',
                'description' => 'fake_plan_description 2',
                'schemas' => nil
            }
          ]
        },
      ]
    }
  end

  def dashboard_client(id=global_broker_id)
    {
      'id' => "#{id}-uaa-id",
      'secret' => 'my-dashboard-secret',
      'redirect_uri' => 'http://example.org'
    }
  end

  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }

  let(:space_developer_headers) {
    user = VCAP::CloudController::User.make
    org.add_user(user)
    space.add_developer(user)

    headers_for(user)
  }

  let(:space_developer_alternate_space_headers) {
    user = VCAP::CloudController::User.make
    space = VCAP::CloudController::Space.make(organization: org)
    org.add_user(user)
    space.add_developer(user)

    headers_for(user)
  }

  let(:org_space_manager_headers) {
    user = VCAP::CloudController::User.make
    set_current_user(user)
    org.add_user(user)
    org.add_auditor(user)
    org.add_manager(user)
    org.add_billing_manager(user)
    space.add_auditor(user)
    space.add_manager(user)

    headers_for(user)
  }

  let(:global_broker_request_body) do
    {
      name: 'broker name',
      url: 'http://example.org/broker-url',
      credentials: {
        type: 'basic',
        data: {
          username: 'admin',
          password: 'welcome',
        }
      }
    }
  end

  let(:space_scoped_broker_request_body) do
    {
      name: 'space-scoped broker name',
      url: 'http://example.org/space-broker-url',
      credentials: {
        type: 'basic',
        data: {
          username: 'admin',
          password: 'welcome',
        },
      },
      relationships: {
        space: {
          data: {
            guid: space.guid
          },
        },
      },
    }
  end

  let(:parsed_body) {
    JSON.parse(last_response.body)
  }

  before do
    stub_request(:get, 'http://example.org/broker-url/v2/catalog').
      to_return(status: 200, body: catalog.to_json, headers: {})
    stub_request(:get, 'http://example.org/space-broker-url/v2/catalog').
      to_return(status: 200, body: catalog(space_broker_id).to_json, headers: {})

    token = { token_type: 'Bearer', access_token: 'my-favourite-access-token' }
    stub_request(:post, 'https://uaa.service.cf.internal/oauth/token').
      to_return(status: 200, body: token.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_uaa_for(global_broker_id)
    stub_uaa_for(space_broker_id)
  end

  describe 'GET /v3/service_brokers' do
    context 'when there are no service brokers' do
      it 'returns 200 OK and an empty list for admin' do
        expect_empty_list(admin_headers)
      end

      it 'returns 200 OK and a list of brokers for admin_read_only' do
        expect_empty_list(admin_read_only_headers)
      end

      it 'returns 200 OK and an empty list for space developer' do
        expect_empty_list(space_developer_headers)
      end

      it 'returns 200 OK and an empty list for org/space auditor/manager' do
        expect_empty_list(org_space_manager_headers)
      end
    end

    context 'when there are global service brokers' do
      let!(:global_service_broker1) { VCAP::CloudController::ServiceBroker.make }
      let!(:global_service_broker2) { VCAP::CloudController::ServiceBroker.make }

      it 'returns 200 OK and a list of brokers for admin' do
        expect_a_list_of_brokers(admin_headers, [global_service_broker1, global_service_broker2])
      end

      it 'returns 200 OK and a list of brokers for admin_read_only' do
        expect_a_list_of_brokers(admin_read_only_headers, [global_service_broker1, global_service_broker2])
      end

      it 'returns 200 OK and an empty list of brokers for space developer' do
        expect_empty_list(space_developer_headers)
      end

      it 'returns 200 OK and an empty list of brokers for org/space auditor/manager' do
        expect_empty_list(org_space_manager_headers)
      end
    end

    context 'when there are spaced-scoped service brokers' do
      let!(:space_scoped_service_broker) { VCAP::CloudController::ServiceBroker.make(space: space) }
      let!(:global_service_broker) { VCAP::CloudController::ServiceBroker.make }

      it 'returns 200 OK and a list of brokers for admin' do
        expect_a_list_of_brokers(admin_headers, [space_scoped_service_broker, global_service_broker])
      end

      it 'returns 200 OK and a list of brokers for admin_read_only' do
        expect_a_list_of_brokers(admin_read_only_headers, [space_scoped_service_broker, global_service_broker])
      end

      it 'returns 200 OK and a list of brokers for space developer' do
        expect_a_list_of_brokers(space_developer_headers, [space_scoped_service_broker])
      end

      it 'returns 200 OK and an empty list of brokers for space developer in another space' do
        expect_empty_list(space_developer_alternate_space_headers)
      end

      it 'returns 200 OK and an empty list of brokers for org/space auditor/manager' do
        expect_empty_list(org_space_manager_headers)
      end
    end

    context 'filters and sorting' do
      let!(:global_service_broker) {
        VCAP::CloudController::ServiceBroker.make(name: 'test-broker-foo')
      }

      let!(:space_scoped_service_broker) {
        VCAP::CloudController::ServiceBroker.make(name: 'test-broker-bar', space: space)
      }

      context 'when requesting one broker per page' do
        it 'returns 200 OK and a body containing one broker with pagination information for the next' do
          expect_filtered_brokers('per_page=1', [global_service_broker])

          expect(parsed_body['pagination']['total_results']).to eq(2)
          expect(parsed_body['pagination']['total_pages']).to eq(2)
        end
      end

      context 'when requesting with a specific order by name' do
        context 'in ascending order' do
          it 'returns 200 OK and a body containg the brokers ordered by created at time' do
            expect_filtered_brokers('order_by=name', [space_scoped_service_broker, global_service_broker])
          end
        end

        context 'descending order' do
          it 'returns 200 OK and a body containg the brokers ordered by created at time' do
            expect_filtered_brokers('order_by=-name', [global_service_broker, space_scoped_service_broker])
          end
        end

        context 'when requesting with a space guid filter' do
          it 'returns 200 OK and a body containing one broker matching the space guid filter' do
            expect_filtered_brokers("space_guids=#{space.guid}", [space_scoped_service_broker])
          end
        end

        context 'when requesting with a space guid filter for another space guid' do
          it 'returns 200 OK and a body containing no brokers' do
            expect_filtered_brokers('space_guids=random-space-guid', [])
          end
        end

        context 'when requesting with a names filter' do
          it 'returns 200 OK and a body containing one broker matching the names filter' do
            expect_filtered_brokers("names=#{global_service_broker.name}", [global_service_broker])
          end
        end
      end
    end

    def expect_filtered_brokers(filter, list)
      get("/v3/service_brokers?#{filter}", {}, admin_headers)

      expect(last_response).to have_status_code(200)
      expect(parsed_body.fetch('resources').length).to eq(list.length)

      list.each_with_index do |broker, index|
        expect(parsed_body['resources'][index]['name']).to eq(broker.name)
      end
    end

    def expect_empty_list(user_headers)
      get('/v3/service_brokers', {}, user_headers)

      expect(last_response).to have_status_code(200)

      expect(parsed_body).to have_key('resources')
      expect(parsed_body['resources'].length).to eq(0)
    end

    def expect_a_list_of_brokers(user_headers, list)
      get('/v3/service_brokers', {}, user_headers)

      expect(last_response).to have_status_code(200)
      expect(parsed_body).to have_key('pagination')
      brokers = parsed_body.fetch('resources')
      expect(brokers.length).to eq(list.length)

      list.each do |expected_broker|
        actual_broker = brokers.find { |b| b.fetch('name') == expected_broker.name }
        expect(actual_broker).to_not be_nil, "Could not find broker with name '#{expected_broker.name}'"
        expect(actual_broker).to match_broker(expected_broker)
      end
    end
  end

  describe 'GET /v3/service_brokers/:guid' do
    context 'when the service broker does not exist' do
      it 'return with 404 Not Found' do
        is_expected.to_not find_broker(broker_guid: 'does-not-exist', with: admin_headers)
      end
    end

    context 'when the service broker is global' do
      let!(:global_service_broker_1) { VCAP::CloudController::ServiceBroker.make }
      let!(:global_service_broker_2) { VCAP::CloudController::ServiceBroker.make }

      it 'returns 200 OK and the broker for admin' do
        expect_broker(global_service_broker_1, with: admin_headers)
      end

      it 'returns 200 OK and the broker for admin_read_only' do
        expect_broker(global_service_broker_2, with: admin_read_only_headers)
      end

      it 'returns 404 Not Found for space developer' do
        is_expected.to_not find_broker(broker_guid: global_service_broker_1.guid, with: space_developer_headers)
      end

      it 'returns 404 Not Found for org/space auditor/manager' do
        is_expected.to_not find_broker(broker_guid: global_service_broker_2.guid, with: org_space_manager_headers)
      end
    end

    context 'when the service broker is space scoped' do
      let!(:space_scoped_service_broker) { VCAP::CloudController::ServiceBroker.make(space: space) }

      it 'returns 200 OK and the broker for admin' do
        expect_broker(space_scoped_service_broker, with: admin_headers)
      end

      it 'returns 200 OK and the broker for admin_read_only' do
        expect_broker(space_scoped_service_broker, with: admin_read_only_headers)
      end

      it 'returns 200 OK and the broker for space developer' do
        expect_broker(space_scoped_service_broker, with: space_developer_headers)
      end

      it 'returns 404 Not Found for space developer in another space' do
        is_expected.to_not find_broker(broker_guid: space_scoped_service_broker.guid, with: space_developer_alternate_space_headers)
      end

      it 'returns 404 Not Found for org/space auditor/manager' do
        is_expected.to_not find_broker(broker_guid: space_scoped_service_broker.guid, with: org_space_manager_headers)
      end
    end

    def expect_broker(expected_broker, with:)
      get("/v3/service_brokers/#{expected_broker.guid}", {}, with)
      expect(last_response.status).to eq(200)
      expect(parsed_body).to match_broker(expected_broker)
    end
  end

  describe 'POST /v3/service_brokers' do
    context 'as admin' do
      context 'when route and volume mount services are enabled' do
        before do
          TestConfig.config[:route_services_enabled] = true
          TestConfig.config[:volume_services_enabled] = true
          create_broker_successfully(global_broker_request_body, with: admin_headers)
        end

        it 'returns 201 Created' do
          expect(last_response).to have_status_code(201)
        end

        it 'creates a service broker entity and synchronizes the catalog' do
          expect_created_broker(global_broker_request_body)
          expect_catalog_synchronized(catalog)
        end

        it 'reports service events' do
          # FIXME: there is an event missing for registering/creating the broker itself by the respective user
          expect([
            { type: 'audit.service.create', actor: 'broker name' },
            { type: 'audit.service.create', actor: 'broker name' },
            { type: 'audit.service_dashboard_client.create', actor: 'broker name' },
            { type: 'audit.service_plan.create', actor: 'broker name' },
            { type: 'audit.service_plan.create', actor: 'broker name' },
          ]).to be_reported_as_events
        end
      end

      context 'when route and volume mount services are disabled' do
        before do
          TestConfig.config[:route_services_enabled] = false
          TestConfig.config[:volume_services_enabled] = false
          create_broker_successfully(global_broker_request_body, with: admin_headers)
        end

        it 'returns 201 Created' do
          expect(last_response).to have_status_code(201)
        end

        it 'creates a service broker entity and synchronizes the catalog' do
          expect_created_broker(global_broker_request_body)
          expect_catalog_synchronized(catalog)
        end

        it 'returns warning in the header' do
          expect(last_response_warnings).
            to eq([
              'Service route_volume_service_name-2 is declared to be a route service but support for route services is disabled.' \
' Users will be prevented from binding instances of this service with routes.',
              'Service route_volume_service_name-2 is declared to be a volume mount service but support for volume mount services is disabled.' \
' Users will be prevented from binding instances of this service with apps.'
            ])
        end

        let(:uaa_uri) { VCAP::CloudController::Config.config.get(:uaa, :internal_url) }
        let(:tx_url) { uaa_uri + '/oauth/clients/tx/modify' }
        it 'creates some UAA stuff' do
          expect(a_request(:post, tx_url)).to have_been_made
        end
      end

      context 'when user provides a malformed request' do
        let(:malformed_body) do
          {
            whatever: 'oopsie'
          }
        end

        it 'responds with a helpful error message' do
          create_broker(malformed_body, with: admin_headers)

          expect(last_response).to have_status_code(422)
          expect(last_response.body).to include('UnprocessableEntity')
          expect(last_response.body).to include('Name must be a string')
        end
      end

      context 'when a broker with the same name exists' do
        before do
          VCAP::CloudController::ServiceBroker.make(name: global_broker_request_body[:name])
          create_broker(global_broker_request_body, with: admin_headers)
        end

        it 'should return 422 and meaningful error, but still creates a broker' do
          expect_no_broker_created
          expect_error(status: 422, error: 'UnprocessableEntity', description: 'Name must be unique')
        end
      end

      context 'when fetching broker catalog fails' do
        before do
          stub_request(:get, 'http://example.org/broker-url/v2/catalog').
            to_return(status: 418, body: {}.to_json)
          create_broker(global_broker_request_body, with: admin_headers)
        end

        it 'returns 502 and does not create the service broker' do
          expect_no_broker_created
          expect_error(status: 502, error: 'CF-ServiceBrokerRequestRejected', description: 'The service broker rejected the request')
        end
      end
    end

    context 'as space developer user' do
      it 'returns 403 when registering a global service broker' do
        create_broker(global_broker_request_body, with: space_developer_headers)

        expect_no_broker_created
        expect_unauthorized
      end

      describe 'registering a space scoped service broker' do
        before do
          create_broker(space_scoped_broker_request_body, with: space_developer_headers)
        end

        it 'returns 201 Created' do
          expect(last_response).to have_status_code(201)
        end

        it 'creates a service broker entity synchronizes the catalog' do
          expect_created_broker(space_scoped_broker_request_body)
          expect_catalog_synchronized(catalog)
        end

        it 'reports service events' do
          # FIXME: there is an event missing for registering/creating the broker itself by the respective user
          expect([
            { type: 'audit.service.create', actor: 'space-scoped broker name' },
            { type: 'audit.service.create', actor: 'space-scoped broker name' },
            { type: 'audit.service_dashboard_client.create', actor: 'space-scoped broker name' },
            { type: 'audit.service_plan.create', actor: 'space-scoped broker name' },
            { type: 'audit.service_plan.create', actor: 'space-scoped broker name' },
          ]).to be_reported_as_events
        end
      end
    end

    context 'as an org/space auditor/manager/billing manager user' do
      it 'returns 403 when registering a global service broker' do
        create_broker(global_broker_request_body, with: org_space_manager_headers)

        expect_no_broker_created
        expect_unauthorized
      end

      it 'returns 403 when registering a space-scoped broker' do
        create_broker(space_scoped_broker_request_body, with: org_space_manager_headers)

        expect_no_broker_created
        expect_unauthorized
      end
    end

    def expect_created_broker(expected_broker)
      expect(VCAP::CloudController::ServiceBroker.count).to eq(@count_before_creation + 1)

      service_broker = VCAP::CloudController::ServiceBroker.last

      expect(service_broker).to include(
        'name' => expected_broker[:name],
        'broker_url' => expected_broker[:url],
        'auth_username' => expected_broker.dig(:credentials, :data, :username),
        'space_guid' => expected_broker.dig(:relationships, :space, :data, :guid),
      )
      # password not exported in to_hash
      expect(service_broker.auth_password).to eq(expected_broker[:credentials][:data][:password])
    end

    def expect_catalog_synchronized(catalog)
      service_broker = VCAP::CloudController::ServiceBroker.last

      services = VCAP::CloudController::Service.where(service_broker_id: service_broker.id)
      expect(services.map(&:label)).to eq(catalog['services'].map { |s| s['name'] })

      services.each_with_index do |service, index|
        plans = VCAP::CloudController::ServicePlan.where(service_id: service.id)
        expect(plans.map(&:name)).to eq(catalog['services'][index]['plans'].map { |p| p['name'] })
      end
    end

    def expect_no_broker_created
      expect(VCAP::CloudController::ServiceBroker.count).to eq(@count_before_creation)
    end
  end

  describe 'DELETE /v3/service_brokers/:guid' do
    let!(:global_broker) {
      create_broker_successfully(global_broker_request_body, with: admin_headers)
    }
    let!(:global_broker_services) { VCAP::CloudController::Service.where(service_broker_id: global_broker.id) }
    let!(:global_broker_plans) { VCAP::CloudController::ServicePlan.where(service_id: global_broker_services.map(&:id)) }

    let!(:space_scoped_service_broker) {
      create_broker_successfully(space_scoped_broker_request_body, with: admin_headers)
    }
    let!(:space_broker_services) { VCAP::CloudController::Service.where(service_broker_id: space_scoped_service_broker.id) }
    let!(:space_broker_plans) { VCAP::CloudController::ServicePlan.where(service_id: space_broker_services.map(&:id)) }

    context 'as an admin user' do
      context 'when the broker does not exist' do
        it 'responds with 404 Not Found' do
          delete_broker('guid-that-does-not-exist', with: admin_headers)
          expect_error(status: 404, error: 'CF-ResourceNotFound', description: 'Service broker not found')
        end
      end

      context 'when there are no service instances' do
        let(:broker) { global_broker }
        let(:broker_services) { global_broker_services }
        let(:broker_plans) { global_broker_plans }
        let(:actor) { 'broker name' }
        let(:user_headers) { admin_headers }
        let(:broker_id) { global_broker_id }

        it_behaves_like 'a successful broker delete'
      end
    end

    context 'as an admin-read-only/global auditor user' do
      it 'fails authorization' do
        delete_broker(global_broker.guid, with: admin_read_only_headers)
        expect_unauthorized

        delete_broker(global_broker.guid, with: global_auditor_headers)
        expect_unauthorized
      end
    end

    context 'as a space developer' do
      context 'with access to the broker' do
        context 'when the broker has no service instances' do
          let(:broker) { space_scoped_service_broker }
          let(:broker_services) { space_broker_services }
          let(:broker_plans) { space_broker_plans }
          let(:actor) { 'space-scoped broker name' }
          let(:user_headers) { space_developer_headers }
          let(:broker_id) { space_broker_id }

          it_behaves_like 'a successful broker delete'
        end
      end

      context 'without access to the broker' do
        it 'fails authorization' do
          delete_broker(space_scoped_service_broker.guid, with: space_developer_alternate_space_headers)
          expect(last_response.status).to eq(404)
        end
      end
    end

    context 'as an org/space auditor/manager/billing manager user' do
      it 'responds with 404 Not Found for global brokers' do
        delete "/v3/service_brokers/#{global_broker.guid}", {}, org_space_manager_headers
        expect(last_response).to have_status_code(404)
      end

      it 'responds with 403 Not Authorized for space-scoped broker' do
        delete "/v3/service_brokers/#{space_scoped_service_broker.guid}", {}, org_space_manager_headers
        expect(last_response).to have_status_code(403)
      end
    end

    def delete_broker(guid, with:)
      delete "/v3/service_brokers/#{guid}", {}, with
    end
  end

  def create_broker(broker_body, with:)
    @count_before_creation = VCAP::CloudController::ServiceBroker.count
    post('/v3/service_brokers', broker_body.to_json, with)
  end

  def create_broker_successfully(broker_body, with:)
    create_broker(broker_body, with: with)
    expect(last_response).to have_status_code(201)
    VCAP::CloudController::ServiceBroker.last
  end

  def last_response_warnings
    last_response.headers['X-Cf-Warnings'].split(',').map { |w| CGI.unescape(w) }
  end

  def expect_error(status:, error: '', description: '')
    expect(last_response).to have_status_code(status)
    expect(last_response.body).to include(error)
    expect(last_response.body).to include(description)
  end

  def expect_unauthorized
    expect_error(
      status: 403,
      error: 'CF-NotAuthorized',
      description: 'You are not authorized to perform the requested action'
    )
  end

  def stub_uaa_for(broker_id)
    stub_request(:get, "https://uaa.service.cf.internal/oauth/clients/#{broker_id}-uaa-id").
      to_return(
        { status: 404, body: {}.to_json, headers: { 'Content-Type' => 'application/json' } },
            { status: 200, body: { client_id: dashboard_client(broker_id)['id'] }.to_json, headers: { 'Content-Type' => 'application/json' } }
        )

    stub_request(:post, 'https://uaa.service.cf.internal/oauth/clients/tx/modify').
      with(
        body: [
          {
                "client_id": "#{broker_id}-uaa-id",
                "client_secret": 'my-dashboard-secret',
                "redirect_uri": 'http://example.org',
                "scope": %w(openid cloud_controller_service_permissions.read),
                "authorities": ['uaa.resource'],
                "authorized_grant_types": ['authorization_code'],
                "action": 'add'
            }
        ].to_json
        ).
      to_return(status: 201, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, 'https://uaa.service.cf.internal/oauth/clients/tx/modify').
      with(
        body: [
          {
                "client_id": "#{broker_id}-uaa-id",
                "client_secret": nil,
                "redirect_uri": nil,
                "scope": %w(openid cloud_controller_service_permissions.read),
                "authorities": ['uaa.resource'],
                "authorized_grant_types": ['authorization_code'],
                "action": 'delete'
            }
        ].to_json
        ).
      to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })
  end
end
