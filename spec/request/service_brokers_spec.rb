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
      authentication: {
        type: 'basic',
        credentials: {
          username: 'admin',
          password: 'welcome',
        }
      }
    }
  end

  let(:global_broker_with_identical_name_body) {
    {
      name: global_broker_request_body[:name],
      url: 'http://example.org/different-broker-url',
      authentication: global_broker_request_body[:authentication]
    }
  }

  let(:global_broker_with_identical_url_body) {
    {
      name: 'different broker name',
      url: global_broker_request_body[:url],
      authentication: global_broker_request_body[:authentication]
    }
  }

  let(:space_scoped_broker_request_body) do
    {
      name: 'space-scoped broker name',
      url: 'http://example.org/space-broker-url',
      authentication: {
        type: 'basic',
        credentials: {
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

  def parsed_body
    JSON.parse(last_response.body)
  end

  before do
    stub_request(:get, 'http://example.org/broker-url/v2/catalog').
      to_return(status: 200, body: catalog.to_json, headers: {})
    stub_request(:get, 'http://example.org/space-broker-url/v2/catalog').
      to_return(status: 200, body: catalog(space_broker_id).to_json, headers: {})
    stub_request(:put, %r{http://example.org/broker-url/v2/service\_instances/.*}).
      to_return(status: 200, body: '{}', headers: {})

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
      let!(:broker_state) { VCAP::CloudController::ServiceBrokerState.make_unsaved }
      let!(:global_service_broker1) { VCAP::CloudController::ServiceBroker.make }
      let!(:global_service_broker2) { VCAP::CloudController::ServiceBroker.make }

      before do
        global_service_broker1.update(service_broker_state: broker_state)
      end

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
      it 'creates a service broker in the database' do
        expect {
          create_broker_successfully(global_broker_request_body, with: admin_headers)
        }.to change {
          VCAP::CloudController::ServiceBroker.count
        }.by(1)

        broker = VCAP::CloudController::ServiceBroker.last
        expect(broker.name).to eq(global_broker_request_body[:name])
        expect(broker.broker_url).to eq(global_broker_request_body[:url])
        expect(broker.auth_username).to eq(global_broker_request_body.dig(:authentication, :credentials, :username))
        expect(broker.auth_password).to eq(global_broker_request_body.dig(:authentication, :credentials, :password))
        expect(broker.space).to be_nil
        expect(broker.service_broker_state.state).to eq(VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZING)
      end

      it 'creates a pollable job to synchronize the catalog and responds with its location' do
        create_broker_successfully(global_broker_request_body, with: admin_headers)

        job = VCAP::CloudController::PollableJobModel.last
        broker = VCAP::CloudController::ServiceBroker.last

        expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
        expect(job.operation).to eq('service_broker.catalog.synchronize')
        expect(job.resource_guid).to eq(broker.guid)
        expect(job.resource_type).to eq('service_brokers')

        expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")
      end

      it 'creates the services and the plans in the database' do
        create_broker_successfully(global_broker_request_body, with: admin_headers)
        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        broker = VCAP::CloudController::ServiceBroker.last
        expect(broker.services.map(&:label)).to include('service_name-1')
        expect(broker.services.map(&:label)).to include('route_volume_service_name-2')
        expect(broker.service_plans.map(&:name)).to include('plan_name-1')
        expect(broker.service_plans.map(&:name)).to include('plan_name-2')
        expect(broker.service_broker_state.state).to eq(VCAP::CloudController::ServiceBrokerStateEnum::AVAILABLE)
      end

      it 'reports service events' do
        create_broker_successfully(global_broker_request_body, with: admin_headers)
        execute_all_jobs(expected_successes: 1, expected_failures: 0)
        broker_create_metadata = {
          'request' =>
            {
              'name' => 'broker name',
              'broker_url' => 'http://example.org/broker-url',
              'auth_username' => 'admin',
              'auth_password' => '[REDACTED]'
            }
        }
        expect([
          { type: 'audit.service.create', actor: 'broker name' },
          { type: 'audit.service.create', actor: 'broker name' },
          { type: 'audit.service_broker.create', actor: admin_headers._generated_email },
          { type: 'audit.service_dashboard_client.create', actor: 'broker name' },
          { type: 'audit.service_plan.create', actor: 'broker name' },
          { type: 'audit.service_plan.create', actor: 'broker name' },
        ]).to be_reported_as_events

        event = VCAP::CloudController::Event.where({ type: 'audit.service_broker.create', actor_name: admin_headers._generated_email }).first
        expect(event.metadata).to eq(broker_create_metadata)
      end

      it 'creates UAA dashboard clients' do
        create_broker_successfully(global_broker_request_body, with: admin_headers)
        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        uaa_uri = VCAP::CloudController::Config.config.get(:uaa, :internal_url)
        tx_url = uaa_uri + '/oauth/clients/tx/modify'
        expect(a_request(:post, tx_url)).to have_been_made
      end

      context 'when fetching broker catalog fails' do
        before do
          stub_request(:get, 'http://example.org/broker-url/v2/catalog').
            to_return(status: 418, body: {}.to_json)
          create_broker_successfully(global_broker_request_body, with: admin_headers)

          execute_all_jobs(expected_successes: 0, expected_failures: 1)
        end

        it 'leaves broker in a non-available failed state' do
          broker = VCAP::CloudController::ServiceBroker.last
          expect(broker.service_broker_state.state).to eq(VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED)
        end

        it 'has failed the job with an appropriate error' do
          job = VCAP::CloudController::PollableJobModel.last

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)

          error = YAML.safe_load(job.cf_api_error)
          expect(error['errors'].first['code']).to eq(10001)
          expect(error['errors'].first['detail']).
            to eq("The service broker rejected the request to http://example.org/broker-url/v2/catalog. Status Code: 418 I'm a Teapot, Body: {}")
        end
      end

      context 'when catalog is not valid' do
        before do
          stub_request(:get, 'http://example.org/broker-url/v2/catalog').
            to_return(status: 200, body: {}.to_json)
          create_broker_successfully(global_broker_request_body, with: admin_headers)

          execute_all_jobs(expected_successes: 0, expected_failures: 1)
        end

        it 'leaves broker in a non-available failed state' do
          broker = VCAP::CloudController::ServiceBroker.last
          expect(broker.service_broker_state.state).to eq(VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED)
        end

        it 'has failed the job with an appropriate error' do
          job = VCAP::CloudController::PollableJobModel.last

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)

          error = YAML.safe_load(job.cf_api_error)
          expect(error['errors'].first['code']).to eq(270012)
          expect(error['errors'].first['detail']).to eq("Service broker catalog is invalid: \nService broker must provide at least one service\n")
        end
      end

      context 'when route and volume mount services are disabled' do
        before do
          TestConfig.config[:route_services_enabled] = false
          TestConfig.config[:volume_services_enabled] = false
          create_broker_successfully(global_broker_request_body, with: admin_headers)
        end

        let(:job) { VCAP::CloudController::PollableJobModel.last }

        it 'returns 202 Accepted and a job' do
          expect(last_response).to have_status_code(202)

          expect(VCAP::CloudController::PollableJobModel.count).to eq(1)
          expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/#{job.guid}))

          get "/v3/jobs/#{job.guid}", {}, admin_headers
          expect(parsed_body).to include({
            'state' => 'PROCESSING',
            'operation' => 'service_broker.catalog.synchronize',
            'links' => {
              'self' => {
                'href' => match(%r(http.+/v3/jobs/#{job.guid}))
              },
              'service_brokers' => {
                'href' => match(%r(http.+/v3/service_brokers/[^/]+))
              }
            }
          })
        end

        it 'creates a service broker entity and does not synchronizes the catalog yet' do
          expect_created_broker(global_broker_request_body)
          expect_catalog_not_synchronized
        end

        context 'when job processing is done and it failed' do
          before do
            execute_all_jobs(expected_successes: 0, expected_failures: 1)
          end

          it 'has failed the job' do
            get "/v3/jobs/#{job.guid}", {}, admin_headers
            expect(parsed_body).to include({
              'state' => 'FAILED',
              'operation' => 'service_broker.catalog.synchronize',
              'errors' => [
                include({
                  'detail' => "Service broker catalog is incompatible: \n" \
                    "Service route_volume_service_name-2 is declared to be a route service but support for route services is disabled.\n" \
                    "Service route_volume_service_name-2 is declared to be a volume mount service but support for volume mount services is disabled.\n",
                  'title' => 'CF-ServiceBrokerCatalogIncompatible',
                  'code' => 270019
                })
              ],
              'links' => {
                'self' => {
                  'href' => match(%r(http.+/v3/jobs/#{job.guid}))
                },
                'service_brokers' => {
                  'href' => match(%r(http.+/v3/service_brokers/[^/]+))
                }
              }
            })
          end

          it 'has failed synchronizing the catalog' do
            expect_catalog_not_synchronized
          end

          it 'leaves the broker in an unavailable state' do
            expect_broker_status(
              available: false,
              status: 'synchronization failed',
              with: admin_headers
            )
          end
        end

        let(:uaa_uri) { VCAP::CloudController::Config.config.get(:uaa, :internal_url) }
        let(:tx_url) { uaa_uri + '/oauth/clients/tx/modify' }
        it 'does not create any UAA dashboard clients' do
          expect(a_request(:post, tx_url)).not_to have_been_made
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
          create_broker(global_broker_with_identical_name_body, with: admin_headers)
        end

        it 'should return 422 and meaningful error and does not create a broker' do
          expect_no_broker_created
          expect_error(status: 422, error: 'UnprocessableEntity', description: 'Name must be unique')
        end
      end

      context 'when another broker with the same name gets created whilst current one is in progress' do
        before do
          create_broker_successfully(global_broker_request_body, with: admin_headers)
          create_broker(global_broker_with_identical_name_body, with: admin_headers)
        end

        it 'should return 422 and meaningful error and does not create a broker' do
          expect_no_broker_created
          expect_error(status: 422, error: 'UnprocessableEntity', description: 'Name must be unique')
        end
      end

      context 'when another broker with the same URL gets created whilst current one is in progress' do
        before do
          create_broker_successfully(global_broker_request_body, with: admin_headers)
          create_broker(global_broker_with_identical_url_body, with: admin_headers)
        end

        it 'should return 202 Accepted and broker created' do
          expect(last_response).to have_status_code(202)
          expect_created_broker(global_broker_with_identical_url_body)
        end
      end

      context 'when a space is provided that the user cannot read' do
        let(:nonexistant_space_broker_body) do
          {
            name: 'space-scoped broker name',
            url: 'http://example.org/space-broker-url',
            authentication: {
              type: 'basic',
              credentials: {
                username: 'admin',
                password: 'welcome',
              },
            },
            relationships: {
              space: {
                data: {
                  guid: 'bad-guid'
                },
              },
            },
          }
        end

        before do
          create_broker(nonexistant_space_broker_body, with: space_developer_headers)
        end

        it 'returns a error saying the space is invalid' do
          expect(last_response).to have_status_code(422)
          expect(last_response.body).to include 'Invalid space. Ensure that the space exists and you have access to it.'
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

        let(:job) { VCAP::CloudController::PollableJobModel.last }

        it 'returns 202 Accepted and a job URL' do
          expect(last_response).to have_status_code(202)

          expect(VCAP::CloudController::PollableJobModel.count).to eq(1)
          expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/#{job.guid}))

          get "/v3/jobs/#{job.guid}", {}, space_developer_headers
          expect(parsed_body).to include({
            'state' => 'PROCESSING',
            'operation' => 'service_broker.catalog.synchronize',
            'links' => {
              'self' => {
                'href' => match(%r(http.+/v3/jobs/#{job.guid}))
              },
              'service_brokers' => {
                'href' => match(%r(http.+/v3/service_brokers/[^/]+))
              }
            }
          })
        end

        it 'creates the broker' do
          broker = VCAP::CloudController::ServiceBroker.last
          expect(broker.name).to eq(space_scoped_broker_request_body[:name])
          expect(broker.broker_url).to eq(space_scoped_broker_request_body[:url])
          expect(broker.auth_password).to eq(space_scoped_broker_request_body.dig(:authentication, :credentials, :password))
          expect(broker.auth_username).to eq(space_scoped_broker_request_body.dig(:authentication, :credentials, :username))
          expect(broker.space.guid).to eq(space_scoped_broker_request_body.dig(:relationships, :space, :data, :guid))
        end

        it 'creates a service broker entity and does not synchronize the catalog yet' do
          expect_created_broker(space_scoped_broker_request_body)
          expect_catalog_not_synchronized
        end

        it 'leaves the broker in a synchronization in progress' do
          expect_broker_status(
            available: false,
            status: 'synchronization in progress',
            with: space_developer_headers
          )
        end

        context 'when job processing is done and it succeeded' do
          before do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end

          it 'has completed the job' do
            get "/v3/jobs/#{job.guid}", {}, space_developer_headers
            expect(parsed_body).to include({
              'state' => 'COMPLETE',
              'operation' => 'service_broker.catalog.synchronize',
              'links' => {
                'self' => {
                  'href' => match(%r(http.+/v3/jobs/#{job.guid}))
                },
                'service_brokers' => {
                  'href' => match(%r(http.+/v3/service_brokers/[^/]+))
                }
              }
            })
          end

          it 'has synchronized the catalog' do
            expect_catalog_synchronized(catalog)
          end

          it 'reports service events' do
            broker_create_metadata = {
              'request' =>
                {
                  'name' => 'space-scoped broker name',
                  'broker_url' => 'http://example.org/space-broker-url',
                  'auth_username' => 'admin',
                  'auth_password' => '[REDACTED]',
                  'space_guid' => space.guid
                }
            }

            expect([
              { type: 'audit.service.create', actor: 'space-scoped broker name' },
              { type: 'audit.service.create', actor: 'space-scoped broker name' },
              { type: 'audit.service_broker.create', actor: space_developer_headers._generated_email },
              { type: 'audit.service_dashboard_client.create', actor: 'space-scoped broker name' },
              { type: 'audit.service_plan.create', actor: 'space-scoped broker name' },
              { type: 'audit.service_plan.create', actor: 'space-scoped broker name' },
            ]).to be_reported_as_events

            event = VCAP::CloudController::Event.where({ type: 'audit.service_broker.create', actor_name: space_developer_headers._generated_email }).first
            expect(event.metadata).to eq(broker_create_metadata)
          end

          it 'leaves the broker in an available state' do
            expect_broker_status(
              available: true,
              status: 'available',
              with: space_developer_headers
            )
          end
        end
      end

      context 'when a space is provided that the user cannot read' do
        let(:other_space_broker_body) do
          {
            name: 'space-scoped broker name',
            url: 'http://example.org/space-broker-url',
            authentication: {
              type: 'basic',
              credentials: {
                username: 'admin',
                password: 'welcome',
              },
            },
            relationships: {
              space: {
                data: {
                  guid: VCAP::CloudController::Space.make.guid
                },
              },
            },
          }
        end

        before do
          create_broker(other_space_broker_body, with: space_developer_headers)
        end

        it 'returns a error saying the space is invalid' do
          expect(last_response).to have_status_code(422)
          expect(last_response.body).to include 'Invalid space. Ensure that the space exists and you have access to it.'
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
        'auth_username' => expected_broker.dig(:authentication, :credentials, :username),
        'space_guid' => expected_broker.dig(:relationships, :space, :data, :guid),
      )

      # asserting password separately because it is not exported in to_hash
      expect(service_broker.auth_password).to eq(expected_broker[:authentication][:credentials][:password])
    end

    def expect_broker_status(available:, status:, with:)
      expect(VCAP::CloudController::ServiceBroker.count).to eq(@count_before_creation + 1)
      service_broker = VCAP::CloudController::ServiceBroker.last

      get("/v3/service_brokers/#{service_broker.guid}", {}, with)
      expect(last_response.status).to eq(200)
      expect(parsed_body).to include(
        'available' => available,
        'status' => status
      )
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

    def expect_catalog_not_synchronized
      service_broker = VCAP::CloudController::ServiceBroker.last
      services = VCAP::CloudController::Service.where(service_broker_id: service_broker.id)
      expect(services).to be_empty
    end

    def expect_no_broker_created
      expect(VCAP::CloudController::ServiceBroker.count).to eq(@count_before_creation)
    end
  end

  describe 'DELETE /v3/service_brokers/:guid' do
    let!(:global_broker) {
      create_broker_successfully(global_broker_request_body, with: admin_headers, wait: true)
    }
    let!(:global_broker_services) { VCAP::CloudController::Service.where(service_broker_id: global_broker.id) }
    let!(:global_broker_plans) { VCAP::CloudController::ServicePlan.where(service_id: global_broker_services.map(&:id)) }

    let!(:space_scoped_service_broker) {
      create_broker_successfully(space_scoped_broker_request_body, with: admin_headers, wait: true)
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

      context 'when there are service instances' do
        before do
          create_service_instance(global_broker, with: admin_headers)
        end

        it 'responds with 422 Unprocessable Entity' do
          delete_broker(global_broker.guid, with: admin_headers)
          expect_error(
            status: 422,
            error: 'CF-ServiceBrokerNotRemovable',
            description: "Can not remove brokers that have associated service instances: #{global_broker.name}"
          )
        end
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

  def create_broker_successfully(broker_body, with:, wait: false)
    create_broker(broker_body, with: with)
    expect(last_response).to have_status_code(202)
    broker = VCAP::CloudController::ServiceBroker.last

    execute_all_jobs(expected_successes: 1, expected_failures: 0) if wait

    broker
  end

  def create_service_instance(broker, with:)
    service = VCAP::CloudController::Service.where(service_broker_id: broker.id).first
    plan = VCAP::CloudController::ServicePlan.where(service_id: service.id).first
    plan.public = true
    plan.save

    request_body = {
      name: 'my-service-instance',
      space_guid: space.guid,
      service_plan_guid: plan.guid
    }
    # TODO: replace this with v3 once it's implemented
    post('/v2/service_instances', request_body.to_json, with)
    expect(last_response).to have_status_code(201)
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
