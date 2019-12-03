require 'spec_helper'
require 'request_spec_shared_examples'
require 'cloud_controller'
require 'services'
require 'messages/service_broker_update_message'

RSpec.describe 'V3 service brokers' do
  let(:user) { VCAP::CloudController::User.make }
  let(:global_broker_id) { 'global-service-id' }
  let(:space_broker_id) { 'space-service-id' }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:space_developer_alternate_space_headers) {
    user = VCAP::CloudController::User.make
    space = VCAP::CloudController::Space.make(organization: org)
    org.add_user(user)
    space.add_developer(user)

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
    let(:api_call) { lambda { |user_headers| get '/v3/service_brokers', nil, user_headers } }

    context 'when there are no service brokers' do
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_objects: []
        )

        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    context 'when there are global service brokers' do
      let(:global_service_broker_v3) do
        # Note, has a state
        VCAP::CloudController::ServiceBroker.make(state: VCAP::CloudController::ServiceBrokerStateEnum::AVAILABLE)
      end

      let(:global_service_broker_v2) do
        # Note, no state set
        VCAP::CloudController::ServiceBroker.make(state: '')
      end

      let(:global_service_broker_v3_json) do
        {
            guid: global_service_broker_v3.guid,
            name: global_service_broker_v3.name,
            url: global_service_broker_v3.broker_url,
            created_at: iso8601,
            updated_at: iso8601,
            status: 'available',
            available: true,
            relationships: {},
            links: { self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/service_brokers\/#{global_service_broker_v3.guid}) } }
        }
      end
      let(:global_service_broker_v2_json) do
        {
            guid: global_service_broker_v2.guid,
            name: global_service_broker_v2.name,
            url: global_service_broker_v2.broker_url,
            created_at: iso8601,
            updated_at: iso8601,
            status: 'available',
            available: true,
            relationships: {},
            links: { self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/service_brokers\/#{global_service_broker_v2.guid}) } }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_objects: []
        )

        h['admin'] = { code: 200, response_objects: [global_service_broker_v3_json, global_service_broker_v2_json] }
        h['admin_read_only'] = { code: 200, response_objects: [global_service_broker_v3_json, global_service_broker_v2_json] }
        h['global_auditor'] = { code: 200, response_objects: [global_service_broker_v3_json, global_service_broker_v2_json] }

        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    context 'when there are spaced-scoped service brokers' do
      let!(:space_scoped_service_broker) { VCAP::CloudController::ServiceBroker.make(space: space) }
      let(:space_scoped_service_broker_json) do
        {
            guid: space_scoped_service_broker.guid,
            name: space_scoped_service_broker.name,
            url: space_scoped_service_broker.broker_url,
            created_at: iso8601,
            updated_at: iso8601,
            status: 'available',
            available: true,
            relationships: {
                space: { data: { guid: space.guid } }
            },
            links: {
                self: {
                    href: %r(#{Regexp.escape(link_prefix)}\/v3\/service_brokers\/#{space_scoped_service_broker.guid})
                },
                space: {
                    href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid})
                }
            }
        }
      end
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_objects: []
        )

        h['admin'] = {
              code: 200,
              response_objects: [space_scoped_service_broker_json]
        }
        h['admin_read_only'] = {
              code: 200,
              response_objects: [space_scoped_service_broker_json]
        }
        h['global_auditor'] = {
              code: 200,
              response_objects: [space_scoped_service_broker_json]
        }
        h['space_developer'] = { code: 200,
              response_objects: [space_scoped_service_broker_json]
        }

        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS

      it 'returns 200 OK and an empty list of brokers for space developer in another space' do
        expect_empty_list(space_developer_alternate_space_headers)
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

          expect(parsed_response['pagination']['total_results']).to eq(2)
          expect(parsed_response['pagination']['total_pages']).to eq(2)
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
      expect(parsed_response.fetch('resources').length).to eq(list.length)

      list.each_with_index do |broker, index|
        expect(parsed_response['resources'][index]['name']).to eq(broker.name)
      end
    end

    def expect_empty_list(user_headers)
      get('/v3/service_brokers', {}, user_headers)

      expect(last_response).to have_status_code(200)

      expect(parsed_response).to have_key('resources')
      expect(parsed_response['resources'].length).to eq(0)
    end
  end

  describe 'GET /v3/service_brokers/:guid' do
    context 'when the service broker does not exist' do
      it 'return with 404 Not Found' do
        is_expected.to_not find_broker(broker_guid: 'does-not-exist', with: admin_headers)
      end
    end

    context 'when the service broker is global' do
      let!(:global_service_broker_v3) { VCAP::CloudController::ServiceBroker.make }
      let(:api_call) { lambda { |user_headers| get "/v3/service_brokers/#{global_service_broker_v3.guid}", nil, user_headers } }

      let(:global_service_broker_v3_json) do
        {
            guid: global_service_broker_v3.guid,
            name: global_service_broker_v3.name,
            url: global_service_broker_v3.broker_url,
            created_at: iso8601,
            updated_at: iso8601,
            status: 'available',
            available: true,
            relationships: {},
            links: { self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/service_brokers\/#{global_service_broker_v3.guid}) } }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)

        h['admin'] = {
            code: 200,
            response_object: global_service_broker_v3_json
        }
        h['admin_read_only'] = {
            code: 200,
            response_object: global_service_broker_v3_json
        }
        h['global_auditor'] = {
            code: 200,
            response_object: global_service_broker_v3_json
        }

        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the service broker is space scoped' do
      let!(:space_scoped_service_broker) { VCAP::CloudController::ServiceBroker.make(space: space) }
      let(:api_call) { lambda { |user_headers| get "/v3/service_brokers/#{space_scoped_service_broker.guid}", nil, user_headers } }

      let(:space_scoped_service_broker_json) do
        {
            guid: space_scoped_service_broker.guid,
            name: space_scoped_service_broker.name,
            url: space_scoped_service_broker.broker_url,
            created_at: iso8601,
            updated_at: iso8601,
            status: 'available',
            available: true,
            relationships: {
                space: { data: { guid: space.guid } }
            },
            links: {
                self: {
                    href: %r(#{Regexp.escape(link_prefix)}\/v3\/service_brokers\/#{space_scoped_service_broker.guid})
                },
                space: {
                    href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid})
                }
            }
        }
      end
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)

        h['admin'] = {
            code: 200,
            response_object: space_scoped_service_broker_json
        }
        h['admin_read_only'] = {
            code: 200,
            response_object: space_scoped_service_broker_json
        }
        h['global_auditor'] = {
            code: 200,
            response_object: space_scoped_service_broker_json
        }
        h['space_developer'] = {
            code: 200,
            response_object: space_scoped_service_broker_json
        }

        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      it 'returns 404 Not Found for space developer in another space' do
        is_expected.to_not find_broker(broker_guid: space_scoped_service_broker.guid, with: space_developer_alternate_space_headers)
      end
    end
  end

  describe 'PATCH /v3/service_brokers/:guid' do
    let!(:broker) do
      VCAP::CloudController::ServiceBroker.make(
        name: 'old-name',
        broker_url: 'http://example.org/old-broker-url',
        auth_username: 'old-admin',
        auth_password: 'not-welcome',
        state: VCAP::CloudController::ServiceBrokerStateEnum::AVAILABLE
      )
    end

    let(:update_request_body) {
      {
          name: 'new-name',
          url: 'http://example.org/new-broker-url',
          authentication: {
              type: 'basic',
              credentials: {
                  username: 'admin',
                  password: 'welcome',
              }
          }
      }
    }

    it 'does not immediately update a service broker in the database' do
      patch("/v3/service_brokers/#{broker.guid}", update_request_body.to_json, admin_headers)

      broker = VCAP::CloudController::ServiceBroker.last
      expect(broker.name).to eq('old-name')
      expect(broker.broker_url).to eq('http://example.org/old-broker-url')
      expect(broker.auth_username).to eq('old-admin')
      expect(broker.auth_password).to eq('not-welcome')
      expect(broker.state).to eq(VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZING)
    end

    it 'creates a pollable job to update the service broker' do
      patch("/v3/service_brokers/#{broker.guid}", update_request_body.to_json, admin_headers)
      expect(last_response).to have_status_code(202)

      job = VCAP::CloudController::PollableJobModel.last

      expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
      expect(job.operation).to eq('service_broker.update')
      expect(job.resource_guid).to eq(broker.guid)
      expect(job.resource_type).to eq('service_brokers')

      expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")
    end

    context 'when the message is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::ServiceBrokerUpdateMessage).to receive(:valid?).and_return false

        dbl = double('Errors', full_messages: ['message is invalid'])
        allow_any_instance_of(VCAP::CloudController::ServiceBrokerUpdateMessage).to receive(:errors).and_return dbl
      end

      it 'returns 422 and renders the errors' do
        patch("/v3/service_brokers/#{broker.guid}", update_request_body.to_json, admin_headers)
        expect(last_response).to have_status_code(422)
        expect(last_response.body).to include('UnprocessableEntity')
        expect(last_response.body).to include('message is invalid')
      end
    end

    context 'when broker does not exist' do
      it 'should return 404' do
        patch('/v3/service_brokers/some-guid', update_request_body.to_json, admin_headers)

        expect(last_response).to have_status_code(404)

        response = parsed_response['errors'].first
        expect(response).to include('title' => 'CF-ResourceNotFound')
        expect(response).to include('detail' => 'Service broker not found')
      end
    end

    context 'when a broker with the same name exists' do
      before do
        VCAP::CloudController::ServiceBroker.make(name: 'another broker')
      end

      it 'should return 422 and meaningful error and does not create a broker' do
        patch("/v3/service_brokers/#{broker.guid}", { name: 'another broker' }.to_json, admin_headers)
        expect_error(status: 422, error: 'UnprocessableEntity', description: 'Name must be unique')
        expect(broker.reload.name).to eq 'old-name'
      end
    end

    context 'global service broker' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:api_call) { ->(user_headers) { patch "/v3/service_brokers/#{broker.guid}", update_request_body.to_json, user_headers } }
        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['admin'] = { code: 202 }
          end
        end

        let(:expected_events) do
          ->(email) do
            [
              { type: 'audit.service_broker.update', actor: email },
            ]
          end
        end
      end
    end

    context 'space service broker' do
      let!(:broker) do
        VCAP::CloudController::ServiceBroker.make(
          name: 'old-name',
          broker_url: 'http://example.org/old-broker-url',
          auth_username: 'old-admin',
          auth_password: 'not-welcome',
          space: space
        )
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:api_call) { ->(user_headers) { patch "/v3/service_brokers/#{broker.guid}", update_request_body.to_json, user_headers } }

        let(:expected_codes_and_responses) {
          Hash.new(code: 422).tap do |h|
            h['admin'] = { code: 202 }
            h['admin_read_only'] = { code: 403 }
            h['global_auditor'] = { code: 403 }
            h['space_developer'] = { code: 202 }
            h['space_auditor'] = { code: 403 }
            h['space_manager'] = { code: 403 }
            h['org_manager'] = { code: 403 }
          end
        }

        let(:expected_events) do
          ->(email) do
            [
              { type: 'audit.service_broker.update', actor: email },
            ]
          end
        end
      end
    end

    context 'when job succeeds with warnings' do
      context 'when warning is a UAA problem' do
        let(:broker) do
          TestConfig.override({ uaa_client_name: nil, uaa_client_secret: nil })
          create_broker_successfully(global_broker_request_body, with: admin_headers, execute_all_jobs: true)
        end

        it 'updates the job status and populates warnings field' do
          patch("/v3/service_brokers/#{broker.guid}", global_broker_request_body.to_json, admin_headers)
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          job_url = last_response['Location']
          get job_url, {}, admin_headers
          expect(parsed_response).to include({
              'state' => 'COMPLETE',
              'operation' => 'service_broker.update',
              'errors' => [],
              'warnings' => [
                include({
                    'detail' => include('Warning: This broker includes configuration for a dashboard client.'),
                })
              ],
          })
        end
      end

      context 'when warning is a catalog problem (deactivated plan, but there is a service instance)' do
        let!(:broker) do
          TestConfig.override({})
          create_broker_successfully(global_broker_request_body, with: admin_headers, execute_all_jobs: true)
        end

        before do
          catalog_with_plan_deactivated = catalog(global_broker_id)
          catalog_with_plan_deactivated['services'][0]['plans'][0]['id'] = 'something-else-id'
          catalog_with_plan_deactivated['services'][0]['plans'][0]['name'] = 'something-else-name'

          WebMock.reset!
          stub_request(:get, 'http://example.org/broker-url/v2/catalog').
            to_return(status: 200, body: catalog_with_plan_deactivated.to_json, headers: {})

          token = { token_type: 'Bearer', access_token: 'my-favourite-access-token' }
          stub_request(:any, 'https://uaa.service.cf.internal/oauth/token').
            to_return(status: 200, body: token.to_json, headers: { 'Content-Type' => 'application/json' })

          stub_uaa_for(global_broker_id)

          VCAP::CloudController::ManagedServiceInstance.make(
            service_plan: VCAP::CloudController::ServicePlan.find(name: 'plan_name-1')
          )
        end

        it 'updates the job status and populates warnings field' do
          patch("/v3/service_brokers/#{broker.guid}", global_broker_request_body.to_json, admin_headers)
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          job_url = last_response['Location']
          get job_url, {}, admin_headers
          expect(parsed_response).to include({
              'state' => 'COMPLETE',
              'operation' => 'service_broker.update',
              'errors' => [],
              'warnings' => [
                include({
                    'detail' => include(
                      'Warning: Service plans are missing from the broker\'s catalog ' \
                  '(http://example.org/broker-url/v2/catalog) but can not be removed from Cloud Foundry while instances exist.' \
                  ' The plans have been deactivated to prevent users from attempting to provision new instances of these plans.' \
                  ' The broker should continue to support bind, unbind, and delete for existing instances; if these operations' \
                  " fail contact your broker provider.\nservice_name-1\n  plan_name-1\n"
                    ),
                })
              ],
          })
        end
      end
    end
  end

  describe 'POST /v3/service_brokers' do
    let(:global_service_broker) do
      {
          guid: UUID_REGEX,
          name: 'broker name',
          url: 'http://example.org/broker-url',
          created_at: iso8601,
          updated_at: iso8601,
          status: 'synchronization in progress',
          available: false,
          relationships: {},
          links: { self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/service_brokers\/#{UUID_REGEX}) } }
      }
    end

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
      expect(broker.state).to eq(VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZING)
    end

    it 'creates a pollable job to synchronize the catalog and responds with job resource' do
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

      job = VCAP::CloudController::PollableJobModel.last
      expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)

      expect(broker.services.map(&:label)).to include('service_name-1')
      expect(broker.services.map(&:label)).to include('route_volume_service_name-2')
      expect(broker.service_plans.map(&:name)).to include('plan_name-1')
      expect(broker.service_plans.map(&:name)).to include('plan_name-2')
      expect(broker.state).to eq(VCAP::CloudController::ServiceBrokerStateEnum::AVAILABLE)
    end

    it 'reports service events' do
      create_broker_successfully(global_broker_request_body, with: admin_headers)
      execute_all_jobs(expected_successes: 1, expected_failures: 0)

      expect([
        { type: 'audit.service.create', actor: 'broker name' },
        { type: 'audit.service.create', actor: 'broker name' },
        { type: 'audit.service_broker.create', actor: admin_headers._generated_email },
        { type: 'audit.service_dashboard_client.create', actor: 'broker name' },
        { type: 'audit.service_plan.create', actor: 'broker name' },
        { type: 'audit.service_plan.create', actor: 'broker name' },
      ]).to be_reported_as_events

      event = VCAP::CloudController::Event.where({ type: 'audit.service_broker.create', actor_name: admin_headers._generated_email }).first
      expect(event.metadata).to eq({
          'request' => {
              'name' => 'broker name',
              'url' => 'http://example.org/broker-url',
              'authentication' => {
                  'type' => 'basic',
                  'credentials' => {
                      'username' => 'admin',
                      'password' => '[PRIVATE DATA HIDDEN]'
                  }
              }
          }
      })
    end

    it 'creates UAA dashboard clients' do
      create_broker_successfully(global_broker_request_body, with: admin_headers)
      execute_all_jobs(expected_successes: 1, expected_failures: 0)

      uaa_uri = VCAP::CloudController::Config.config.get(:uaa, :internal_url)
      tx_url = uaa_uri + '/oauth/clients/tx/modify'
      expect(a_request(:post, tx_url)).to have_been_made
    end

    context 'global service broker' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:api_call) { lambda { |user_headers| post '/v3/service_brokers', global_broker_request_body.to_json, user_headers } }
        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['admin'] = { code: 202 }
          end
        end

        let(:after_request_check) { lambda { assert_broker_state(global_service_broker) } }

        let(:expected_events) do
          lambda do |email|
            [
              { type: 'audit.service.create', actor: 'broker name' },
              { type: 'audit.service.create', actor: 'broker name' },
              { type: 'audit.service_broker.create', actor: email },
              { type: 'audit.service_dashboard_client.create', actor: 'broker name' },
              { type: 'audit.service_plan.create', actor: 'broker name' },
              { type: 'audit.service_plan.create', actor: 'broker name' }
            ]
          end
        end
      end
    end

    context 'space-scoped service broker' do
      let(:space_scoped_service_broker) do
        {
            guid: UUID_REGEX,
            name: 'space-scoped broker name',
            url: 'http://example.org/space-broker-url',
            created_at: iso8601,
            updated_at: iso8601,
            status: 'synchronization in progress',
            available: false,
            relationships: {
                space: { data: { guid: space.guid } }
            },
            links: {
                self: {
                    href: %r(#{Regexp.escape(link_prefix)}\/v3\/service_brokers\/#{UUID_REGEX})
                },
                space: {
                    href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid})
                }
            }
        }
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:api_call) { lambda { |user_headers| post '/v3/service_brokers', space_scoped_broker_request_body.to_json, user_headers } }

        let(:expected_codes_and_responses) {
          Hash.new(code: 422).tap do |h|
            h['admin'] = { code: 202 }
            h['admin_read_only'] = { code: 403 }
            h['global_auditor'] = { code: 403 }
            h['space_developer'] = { code: 202 }
            h['space_auditor'] = { code: 403 }
            h['space_manager'] = { code: 403 }
            h['org_manager'] = { code: 403 }
          end
        }

        let(:after_request_check) do
          lambda do
            assert_broker_state(space_scoped_service_broker)
          end
        end
      end
    end

    context 'when job succeeds with warnings' do
      context 'when warning is a UAA problem' do
        before do
          TestConfig.override({ uaa_client_name: nil, uaa_client_secret: nil })
          create_broker_successfully(global_broker_request_body, with: admin_headers)
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end

        it 'updates the job status and populates warnings field' do
          job_url = last_response['Location']
          get job_url, {}, admin_headers
          expect(parsed_response).to include({
              'state' => 'COMPLETE',
              'operation' => 'service_broker.catalog.synchronize',
              'errors' => [],
              'warnings' => [
                include({
                    'detail' => include('Warning: This broker includes configuration for a dashboard client.'),
                })
              ],
          })
        end
      end
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
        expect(broker.state).to eq(VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED)
      end

      it 'has failed the job with an appropriate error' do
        job = VCAP::CloudController::PollableJobModel.last

        expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
        expect(job.cf_api_error).not_to be_nil
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
        expect(broker.state).to eq(VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED)
      end

      it 'has failed the job with an appropriate error' do
        job = VCAP::CloudController::PollableJobModel.last

        expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)

        cf_api_error = job.cf_api_error
        expect(cf_api_error).not_to be_nil
        error = YAML.safe_load(cf_api_error)
        expect(error['errors'].first['code']).to eq(270012)
        expect(error['errors'].first['detail']).to eq("Service broker catalog is invalid: \nService broker must provide at least one service\n")
      end
    end

    context 'when synchronizing UAA clients fails' do
      before do
        VCAP::CloudController::ServiceDashboardClient.make(
          uaa_id: dashboard_client['id']
        )

        create_broker_successfully(global_broker_request_body, with: admin_headers)

        execute_all_jobs(expected_successes: 0, expected_failures: 1)
      end

      let(:job) { VCAP::CloudController::PollableJobModel.last }

      it 'leaves broker in a non-available failed state' do
        expect_broker_status(
          available: false,
          status: 'synchronization failed',
          with: admin_headers
        )
      end

      it 'has failed the job with an appropriate error' do
        get "/v3/jobs/#{job.guid}", {}, admin_headers
        expect(parsed_response).to include(
          'state' => 'FAILED',
          'operation' => 'service_broker.catalog.synchronize',
          'errors' => [
            include(
              'code' => 270012,
              'detail' => "Service broker catalog is invalid: \nService service_name-1\n  Service dashboard client id must be unique\n"
              )
          ],
          'links' => {
              'self' => {
                  'href' => match(%r(http.+/v3/jobs/#{job.guid}))
              },
              'service_brokers' => {
                  'href' => match(%r(http.+/v3/service_brokers/[^/]+))
              }
          }
        )
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

      let(:space_developer_headers) {
        user = VCAP::CloudController::User.make
        org.add_user(user)
        space.add_developer(user)
        headers_for(user)
      }

      before do
        create_broker(other_space_broker_body, with: space_developer_headers)
      end

      it 'returns a error saying the space is invalid' do
        expect(last_response).to have_status_code(422)
        expect(last_response.body).to include 'Invalid space. Ensure that the space exists and you have access to it.'
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
      expect(parsed_response).to include(
        'available' => available,
        'status' => status
      )
    end

    def expect_no_broker_created
      expect(VCAP::CloudController::ServiceBroker.count).to eq(@count_before_creation)
    end

    def assert_broker_state(broker_json)
      job_location = last_response.headers['Location']
      get job_location, {}, admin_headers
      expect(last_response.status).to eq(200)
      broker_url = parsed_response.dig('links', 'service_brokers', 'href')

      get broker_url, {}, admin_headers
      expect(last_response.status).to eq(200)
      expect(parsed_response).to match_json_response(broker_json)

      execute_all_jobs(expected_successes: 1, expected_failures: 0)

      get broker_url, {}, admin_headers
      expect(last_response.status).to eq(200)

      updated_service_broker_json = broker_json.tap do |broker|
        broker[:status] = 'available'
        broker[:available] = true
      end

      expect(parsed_response).to match_json_response(updated_service_broker_json)
    end
  end

  describe 'DELETE /v3/service_brokers/:guid' do
    let!(:global_broker) {
      create_broker_successfully(global_broker_request_body, with: admin_headers, execute_all_jobs: true)
    }
    let!(:global_broker_services) { VCAP::CloudController::Service.where(service_broker_id: global_broker.id) }
    let!(:global_broker_plans) { VCAP::CloudController::ServicePlan.where(service_id: global_broker_services.map(&:id)) }

    context 'when there are no service instances' do
      let(:broker) { global_broker }
      let(:api_call) { lambda { |user_headers| delete "/v3/service_brokers/#{broker.guid}", nil, user_headers } }
      let(:db_check) {
        lambda do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          get "/v3/service_brokers/#{broker.guid}", {}, admin_headers
          expect(last_response.status).to eq(404)
        end
      }

      context 'global broker' do
        let(:broker) { global_broker }
        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS do
          let(:expected_codes_and_responses) {
            Hash.new(code: 404).tap do |h|
              h['admin'] = { code: 202 }
              h['admin_read_only'] = { code: 403 }
              h['global_auditor'] = { code: 403 }
            end
          }
        end
      end

      context 'space-scoped broker' do
        let(:broker) {  VCAP::CloudController::ServiceBroker.make(space_id: space.id) }

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS do
          let(:expected_codes_and_responses) {
            Hash.new(code: 403).tap do |h|
              h['admin'] = { code: 202 }
              h['space_developer'] = { code: 202 }
              h['org_auditor'] = { code: 404 }
              h['org_billing_manager'] = { code: 404 }
              h['no_role'] = { code: 404 }
            end
          }
        end
      end

      context 'a successful delete' do
        before do
          VCAP::CloudController::Event.dataset.destroy
          delete "/v3/service_brokers/#{global_broker.guid}", {}, admin_headers
          expect(last_response).to have_status_code(202)
        end

        context 'while the job is processing' do
          it 'is marked as processing' do
            job_url = last_response['Location']
            get job_url, {}, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response).to include({
                'state' => 'PROCESSING',
                'operation' => 'service_broker.delete'
            })
          end

          it 'does not delete the broker' do
            get "/v3/service_brokers/#{global_broker.guid}", {}, admin_headers
            expect(last_response.status).to eq(200)
          end

          it 'marks the broker as deleting' do
            get "/v3/service_brokers/#{global_broker.guid}", {}, admin_headers
            expect(parsed_response).to include({
                'available' => false,
                'status' => 'delete in progress'
            })
          end
        end

        context 'when the job is completed' do
          before do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end

          it 'marks the job as complete' do
            job_url = last_response['Location']
            get job_url, {}, admin_headers
            expect(last_response).to have_status_code(200)
            expect(parsed_response).to include({
                'state' => 'COMPLETE',
                'operation' => 'service_broker.delete'
            })
          end

          it 'deletes the UAA clients related to this broker' do
            uaa_client_id = "#{global_broker_id}-uaa-id"
            expect(VCAP::CloudController::ServiceDashboardClient.find_client_by_uaa_id(uaa_client_id)).to be_nil

            expect(a_request(:post, 'https://uaa.service.cf.internal/oauth/clients/tx/modify').
                with(
                  body: [
                    {
                          "client_id": uaa_client_id,
                          "client_secret": nil,
                          "redirect_uri": nil,
                          "scope": %w(openid cloud_controller_service_permissions.read),
                          "authorities": ['uaa.resource'],
                          "authorized_grant_types": ['authorization_code'],
                          "action": 'delete'
                      }
                  ].to_json
                )).to have_been_made
          end

          it 'emits service and plan deletion events, and broker deletion event' do
            expect([
              { type: 'audit.service.delete', actor: 'broker name' },
              { type: 'audit.service.delete', actor: 'broker name' },
              { type: 'audit.service_broker.delete', actor: admin_headers._generated_email },
              { type: 'audit.service_dashboard_client.delete', actor: 'broker name' },
              { type: 'audit.service_plan.delete', actor: 'broker name' },
              { type: 'audit.service_plan.delete', actor: 'broker name' }
            ]).to be_reported_as_events
          end

          it 'deletes the associated service offerings and plans' do
            services = VCAP::CloudController::Service.where(id: global_broker_services.map(&:id))
            expect(services).to have(0).items

            plans = VCAP::CloudController::ServicePlan.where(id: global_broker_plans.map(&:id))
            expect(plans).to have(0).items
          end
        end
      end

      context 'when the job fails to execute' do
        job_url = nil
        before do
          allow_any_instance_of(VCAP::Services::ServiceBrokers::ServiceBrokerRemover).to receive(:remove).and_raise('error')
          allow_any_instance_of(ErrorPresenter).to receive(:raise_500?).and_return(false)
          delete "/v3/service_brokers/#{global_broker.guid}", {}, admin_headers
          expect(last_response).to have_status_code(202)
          job_url = last_response['Location']

          execute_all_jobs(expected_successes: 0, expected_failures: 1)
        end

        it 'marks the job as failed' do
          get job_url, {}, admin_headers
          expect(last_response).to have_status_code(200)
          expect(parsed_response).to include({
              'state' => 'FAILED',
              'operation' => 'service_broker.delete',
              'errors' => [include({ 'detail' => include('An unknown error occurred') })]
          })
        end

        it 'does not delete the broker' do
          get "/v3/service_brokers/#{global_broker.guid}", {}, admin_headers
          expect(last_response.status).to eq(200)
        end

        it 'updates the broker state' do
          get "/v3/service_brokers/#{global_broker.guid}", {}, admin_headers
          expect(parsed_response).to include({
              'available' => false,
              'status' => 'delete failed'
          })
        end
      end
    end

    context 'when the broker does not exist' do
      before do
        delete '/v3/service_brokers/guid-that-does-not-exist', {}, admin_headers
      end

      it 'responds with 404 Not Found' do
        expect(last_response).to have_status_code(404)

        response = parsed_response['errors'].first
        expect(response).to include('title' => 'CF-ResourceNotFound')
        expect(response).to include('detail' => 'Service broker not found')
      end
    end

    context 'when there are service instances' do
      before do
        create_service_instance(global_broker, with: admin_headers)
        delete "/v3/service_brokers/#{global_broker.guid}", {}, admin_headers
      end

      it 'responds with 422 Unprocessable entity' do
        expect(last_response).to have_status_code(422)

        response = parsed_response['errors'].first
        expect(response).to include('title' => 'CF-ServiceBrokerNotRemovable')
        expect(response).to include('detail' => "Can not remove brokers that have associated service instances: #{global_broker.name}")
      end
    end
  end

  def create_broker(broker_body, with:)
    @count_before_creation = VCAP::CloudController::ServiceBroker.count
    post('/v3/service_brokers', broker_body.to_json, with)
  end

  def create_broker_successfully(broker_body, with:, execute_all_jobs: false)
    create_broker(broker_body, with: with)
    expect(last_response).to have_status_code(202)
    broker = VCAP::CloudController::ServiceBroker.last

    execute_all_jobs(expected_successes: 1, expected_failures: 0) if execute_all_jobs

    broker
  end

  def expect_error(status:, error: '', description: '')
    expect(last_response).to have_status_code(status)
    expect(last_response.body).to include(error)
    expect(last_response.body).to include(description)
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
                "action": 'update,secret'
            }
        ].to_json
        )
  end

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
end
