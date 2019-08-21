require 'spec_helper'

RSpec.describe 'V3 service brokers' do
  def catalog
    {
        'services' => [
            {
                'id' => 'service_id-1',
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
                ]
            },
            {
                'id' => 'service_id-2',
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

  let(:parsed_body) {
    JSON.parse(last_response.body)
  }

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
        expect_broker_to_match(expected: expected_broker, actual: actual_broker)
      end
    end
  end

  describe 'GET /v3/service_brokers/:guid' do
    context 'when the service broker does not exist' do
      it 'return with 404 Not Found' do
        expect_broker_not_found('does-not-exist', with: admin_headers)
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
        expect_broker_not_found(global_service_broker_1.guid, with: space_developer_headers)
      end

      it 'returns 404 Not Found for org/space auditor/manager' do
        expect_broker_not_found(global_service_broker_2.guid, with: org_space_manager_headers)
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
        expect_broker_not_found(space_scoped_service_broker.guid, with: space_developer_alternate_space_headers)
      end

      it 'returns 404 Not Found for org/space auditor/manager' do
        expect_broker_not_found(space_scoped_service_broker.guid, with: org_space_manager_headers)
      end
    end

    def expect_broker_not_found(guid, with:)
      get("/v3/service_brokers/#{guid}", {}, with)
      expect(last_response.status).to eq(404)
    end

    def expect_broker(expected_broker, with:)
      get("/v3/service_brokers/#{expected_broker.guid}", {}, with)
      expect(last_response.status).to eq(200)
      expect_broker_to_match(expected: expected_broker, actual: parsed_body)
    end
  end

  describe 'POST /v3/service_brokers' do
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
          url: 'http://example.org/broker-url',
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

    before do
      stub_request(:get, 'http://example.org/broker-url/v2/catalog').
          to_return(status: 200, body: catalog.to_json, headers: {})
    end

    def create_broker(broker_body, with:)
      @count_before_creation = VCAP::CloudController::ServiceBroker.count
      post('/v3/service_brokers', broker_body.to_json, with)
    end

    context 'as admin' do
      context 'when route and volume mount services are enabled' do
        before do
          TestConfig.config[:route_services_enabled] = true
          TestConfig.config[:volume_services_enabled] = true
          create_broker(global_broker_request_body, with: admin_headers)
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
          expect_events([
                            {type: 'audit.service.create', actor: 'broker name'},
                            {type: 'audit.service.create', actor: 'broker name'},
                            {type: 'audit.service_plan.create', actor: 'broker name'},
                            {type: 'audit.service_plan.create', actor: 'broker name'},
                        ])
        end
      end

      context 'when route and volume mount services are disabled' do
        before do
          TestConfig.config[:route_services_enabled] = false
          TestConfig.config[:volume_services_enabled] = false
          create_broker(global_broker_request_body, with: admin_headers)
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
        expect_error(status: 403, error: 'CF-NotAuthorized', description: 'You are not authorized to perform the requested action')
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
          expect_events([
                            {type: 'audit.service.create', actor: 'space-scoped broker name'},
                            {type: 'audit.service.create', actor: 'space-scoped broker name'},
                            {type: 'audit.service_plan.create', actor: 'space-scoped broker name'},
                            {type: 'audit.service_plan.create', actor: 'space-scoped broker name'},
                        ])
        end
      end
    end

    context 'as an org/space auditor/manager/billing manager user' do
      it 'returns 403 when registering a global service broker' do
        create_broker(global_broker_request_body, with: org_space_manager_headers)

        expect_no_broker_created
        expect_error(status: 403, error: 'CF-NotAuthorized', description: 'You are not authorized to perform the requested action')
      end

      it 'returns 403 when registering a space-scoped broker' do
        create_broker(space_scoped_broker_request_body, with: org_space_manager_headers)

        expect_no_broker_created
        expect_error(status: 403, error: 'CF-NotAuthorized', description: 'You are not authorized to perform the requested action')
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

    def expect_events(expected_events)
      events = VCAP::CloudController::Event.all
      expect(events.map { |e| {type: e.type, actor: e.actor_name} }).to eq(expected_events)
    end

    def expect_no_broker_created
      expect(VCAP::CloudController::ServiceBroker.count).to eq(@count_before_creation)
    end

    def expect_error(status:, error: '', description: '')
      expect(last_response).to have_status_code(status)
      expect(last_response.body).to include(error)
      expect(last_response.body).to include(description)
    end
  end

  describe 'DELETE /v3/service_brokers/:guid' do
    let!(:global_service_broker) { VCAP::CloudController::ServiceBroker.make }
    let!(:space_scoped_service_broker) { VCAP::CloudController::ServiceBroker.make(space: space) }

    context 'as an admin user' do
      # what about space scoped?
      # what about when there are SIs?
      context 'when the broker does not exist' do
        xit 'responds with 404 Not Found' do
          delete '/v3/service_brokers/guid-that-does-not-exist', {}, admin_headers
          expect(last_response).to have_status_code(404)
        end
      end

      context 'there are no service instances' do
        xit 'returns 204 No Content' do
        end
      end
    end

    context 'as an admin-read-only user' do
      it 'fails authorization' do
        delete("/v3/service_brokers/#{global_service_broker.guid}", {}, admin_read_only_headers)

        expect(last_response).to have_status_code(403)
      end
    end

    context 'as an org/space auditor/manager/billing manager user' do
      xit 'responds with 404 Not Found' do
        delete "/v3/service_brokers/#{global_service_broker.guid}", {}, org_space_manager_headers
        expect(last_response).to have_status_code(404)

        delete "/v3/service_brokers/#{space_scoped_service_broker.guid}", {}, org_space_manager_headers
        expect(last_response).to have_status_code(404)
      end
    end
  end

  def expect_broker_to_match(actual:, expected:)
    expect(actual['url']).to eq(expected.broker_url)
    expect(actual['created_at']).to eq(expected.created_at.iso8601)
    expect(actual['updated_at']).to eq(expected.updated_at.iso8601)
    expect(actual).to have_key('links')
    expect(actual['links']).to have_key('self')
    expect(actual['links']['self']['href']).to include("/v3/service_brokers/#{expected.guid}")

    if expected.space.nil?
      expect(actual['relationships'].length).to eq(0)
      expect(actual['links']).not_to have_key('space')
    else
      expect(actual['relationships'].length).to eq(1)
      expect(actual['relationships']['space']).to have_key('data')
      expect(actual['relationships']['space']['data']['guid']).to eq(expected.space.guid)
      expect(actual['links']).to have_key('space')
      expect(actual['links']['space']['href']).to include("/v3/spaces/#{expected.space.guid}")
    end
  end

  def last_response_warnings
    last_response.headers['X-Cf-Warnings'].split(',').map { |w| CGI.unescape(w) }
  end
end
