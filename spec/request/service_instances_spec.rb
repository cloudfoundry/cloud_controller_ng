require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'V3 service instances' do
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:another_space) { VCAP::CloudController::Space.make }

  describe 'GET /v3/service_instances/:guid' do
    let(:api_call) { lambda { |user_headers| get "/v3/service_instances/#{guid}", nil, user_headers } }

    context 'no such instance' do
      let(:guid) { 'no-such-guid' }

      let(:expected_codes_and_responses) do
        Hash.new(code: 404)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'managed service instance' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: create_managed_json(instance),
        )
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'user-provided service instance' do
      let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: create_user_provided_json(instance),
        )
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'shared service instance' do
      let(:another_space) { VCAP::CloudController::Space.make }
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space) }
      let(:guid) { instance.guid }

      before do
        instance.add_shared_space(space)
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: create_managed_json(instance),
        )

        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'fields' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
      let(:guid) { instance.guid }

      it 'can include the space and organization name fields' do
        get "/v3/service_instances/#{guid}?fields[space.organization]=name,guid", nil, admin_headers
        expect(last_response).to have_status_code(200)

        included = {
            organizations: [
              {
                  name: space.organization.name,
                  guid: space.organization.guid
              }
            ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: included })
      end
    end
  end

  describe 'GET /v3/service_instances' do
    let(:api_call) { lambda { |user_headers| get '/v3/service_instances', nil, user_headers } }

    let!(:msi_1) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let!(:msi_2) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space) }
    let!(:upsi_1) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }
    let!(:upsi_2) { VCAP::CloudController::UserProvidedServiceInstance.make(space: another_space) }
    let!(:ssi) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space) }

    before do
      ssi.add_shared_space(space)
    end

    describe 'list query parameters' do
      let(:user_header) { admin_headers }
      let(:request) { 'v3/service_instances' }
      let(:message) { VCAP::CloudController::ServiceInstancesListMessage }

      let(:params) do
        {
          names: ['foo', 'bar'],
          space_guids: ['foo', 'bar'],
          per_page: '10',
          page: 2,
          order_by: 'updated_at',
          label_selector: 'foo,bar',
          type: 'managed',
          service_plan_guids: ['guid-1', 'guid-2'],
          service_plan_names: ['plan-1', 'plan-2'],
          fields: { 'space.organization' => 'name' }
        }
      end

      it_behaves_like 'request_spec_shared_examples.rb list query endpoint'
    end

    describe 'permissions' do
      let(:all_instances) do
        {
          code: 200,
          response_objects: [
            create_managed_json(msi_1),
            create_managed_json(msi_2),
            create_user_provided_json(upsi_1),
            create_user_provided_json(upsi_2),
            create_managed_json(ssi),
          ]
        }
      end

      let(:space_instances) do
        {
          code: 200,
          response_objects: [
            create_managed_json(msi_1),
            create_user_provided_json(upsi_1),
            create_managed_json(ssi),
          ]
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_objects: []
        )

        h['admin'] = all_instances
        h['admin_read_only'] = all_instances
        h['global_auditor'] = all_instances
        h['space_developer'] = space_instances
        h['space_manager'] = space_instances
        h['space_auditor'] = space_instances
        h['org_manager'] = space_instances

        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    describe 'pagination' do
      let(:resources) { [msi_1, msi_2, upsi_1, upsi_2, ssi] }
      it_behaves_like 'paginated response', '/v3/service_instances'
    end

    describe 'filters' do
      it 'filters by name' do
        get "/v3/service_instances?names=#{msi_1.name}", nil, admin_headers
        check_filtered_instances(create_managed_json(msi_1))
      end

      it 'filters by space guid' do
        get "/v3/service_instances?space_guids=#{another_space.guid}", nil, admin_headers
        check_filtered_instances(
          create_managed_json(msi_2),
          create_user_provided_json(upsi_2),
          create_managed_json(ssi),
        )
      end

      it 'filters by label' do
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'fruit', value: 'strawberry', service_instance: msi_1)
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'fruit', value: 'raspberry', service_instance: msi_2)
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'fruit', value: 'strawberry', service_instance: ssi)
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'fruit', value: 'strawberry', service_instance: upsi_2)

        get '/v3/service_instances?label_selector=fruit=strawberry', nil, admin_headers

        check_filtered_instances(
          create_managed_json(msi_1, labels: { fruit: 'strawberry' }),
          create_user_provided_json(upsi_2, labels: { fruit: 'strawberry' }),
          create_managed_json(ssi, labels: { fruit: 'strawberry' }),
        )
      end

      it 'filters by type' do
        get '/v3/service_instances?type=managed', nil, admin_headers
        check_filtered_instances(
          create_managed_json(msi_1),
          create_managed_json(msi_2),
          create_managed_json(ssi),
        )
      end

      it 'filters by service_plan_guids' do
        get "/v3/service_instances?service_plan_guids=#{msi_1.service_plan.guid},#{msi_2.service_plan.guid}", nil, admin_headers
        check_filtered_instances(
          create_managed_json(msi_1),
          create_managed_json(msi_2)
        )
      end

      it 'filters by service_plan_names' do
        get "/v3/service_instances?service_plan_names=#{msi_1.service_plan.name},#{msi_2.service_plan.name}", nil, admin_headers
        check_filtered_instances(
          create_managed_json(msi_1),
          create_managed_json(msi_2)
        )
      end

      def check_filtered_instances(*instances)
        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].length).to be(instances.length)
        expect({ resources: parsed_response['resources'] }).to match_json_response(
          { resources: instances }
        )
      end
    end

    context 'fields' do
      it 'can include the space and organization name fields' do
        get '/v3/service_instances?fields[space.organization]=name', nil, admin_headers
        expect(last_response).to have_status_code(200)

        included = {
          spaces: [
            {
              name: space.name,
              guid: space.guid,
              relationships: {
                organization: {
                  data: {
                    guid: space.organization.guid
                  }
                }
              }
            },
            {
              name: another_space.name,
              guid: another_space.guid,
              relationships: {
                organization: {
                  data: {
                    guid: another_space.organization.guid
                  }
                }
              }
            }
          ],
          organizations: [
            {
              name: space.organization.name,
              guid: space.organization.guid
            },
            {
              name: another_space.organization.name,
              guid: another_space.organization.guid
            }
          ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: included })
      end
    end
  end

  describe 'GET /v3/service_instances/:guid/credentials' do
    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:api_call) { lambda { |user_headers| get "/v3/service_instances/#{guid}/credentials", nil, user_headers } }
      let(:credentials) { { 'fake-key' => 'fake-value' } }
      let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, credentials: credentials) }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: credentials,
        )

        h['global_auditor'] = { code: 403 }
        h['space_manager'] = { code: 403 }
        h['space_auditor'] = { code: 403 }
        h['org_manager'] = { code: 403 }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end
    end

    it 'responds with an empty obect when no credentials were set' do
      upsi = VCAP::CloudController::UserProvidedServiceInstance.make(space: space, credentials: nil)
      get "/v3/service_instances/#{upsi.guid}/credentials", nil, admin_headers
      expect(last_response).to have_status_code(200)
      expect(parsed_response).to match_json_response({})
    end

    it 'responds with 404 when the instance does not exist' do
      get '/v3/service_instances/does-not-exist/credentials', nil, admin_headers
      expect(last_response).to have_status_code(404)
    end

    it 'responds with 404 for a managed service instance' do
      msi = VCAP::CloudController::ManagedServiceInstance.make(space: space)
      get "/v3/service_instances/#{msi.guid}/credentials", nil, admin_headers
      expect(last_response).to have_status_code(404)
    end
  end

  describe 'GET /v3/service_instances/:guid/parameters' do
    let(:service) { VCAP::CloudController::Service.make(instances_retrievable: true) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service) }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }
    let(:body) { {}.to_json }
    let(:response_code) { 200 }

    before do
      stub_request(:get, %r{#{instance.service.service_broker.broker_url}/v2/service_instances/#{guid_pattern}}).
        with(basic_auth: basic_auth(service_broker: instance.service.service_broker)).
        to_return(status: response_code, body: body)
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:api_call) { lambda { |user_headers| get "/v3/service_instances/#{guid}/parameters", nil, user_headers } }
      let(:parameters) { { 'some-key' => 'some-value' } }
      let(:body) { { 'parameters' => parameters }.to_json }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: parameters,
        )

        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end
    end

    context 'when the instance does not support retrievable instances' do
      let(:service) { VCAP::CloudController::Service.make(instances_retrievable: false) }

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(include({
          'detail' => 'This service does not support fetching service instance parameters.',
          'title' => 'CF-ServiceFetchInstanceParametersNotSupported',
          'code' => 120004,
        }))
      end
    end

    context 'when the broker returns no parameters' do
      it 'returns an empty object' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response).to match_json_response({})
      end
    end

    context 'when the broker returns invalid parameters' do
      let(:body) { { 'parameters' => 'not valid' }.to_json }

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(502)
        expect(parsed_response['errors']).to include(include({
          'title' => 'CF-ServiceBrokerResponseMalformed',
          'code' => 10001,
        }))
      end
    end

    context 'when the broker returns invalid JSON' do
      let(:body) { 'this is not json' }

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(502)
        expect(parsed_response['errors']).to include(include({
          'title' => 'CF-ServiceBrokerResponseMalformed',
          'code' => 10001,
        }))
      end
    end

    context 'when the broker returns a non-200 response code' do
      let(:response_code) { 500 }

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(502)
        expect(parsed_response['errors']).to include(include({
          'title' => 'CF-ServiceBrokerBadResponse',
          'code' => 10001,
        }))
      end
    end

    context 'when the broker returns a 422 (update in progress) response code' do
      let(:response_code) { 422 }

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(502)
        expect(parsed_response['errors']).to include(include({
          'title' => 'CF-ServiceBrokerBadResponse',
          'code' => 10001,
        }))
      end
    end

    context 'when the instance is shared' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:api_call) { lambda { |user_headers| get "/v3/service_instances/#{guid}/parameters", nil, user_headers } }
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space, service_plan: service_plan) }
        let(:parameters) { { 'some-key' => 'some-value' } }
        let(:body) { { 'parameters' => parameters }.to_json }
        let(:guid) { instance.guid }

        before do
          instance.add_shared_space(space)
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: parameters,
          )

          h['space_developer'] = { code: 403 }
          h['space_manager'] = { code: 403 }
          h['space_auditor'] = { code: 403 }
          h['org_manager'] = { code: 403 }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h
        end
      end
    end

    context 'when the instance does not exist' do
      it 'responds with 404' do
        get '/v3/service_instances/does-not-exist/parameters', nil, admin_headers
        expect(last_response).to have_status_code(404)
      end
    end

    context 'when the instance is user-provided' do
      it 'responds with 404' do
        upsi = VCAP::CloudController::UserProvidedServiceInstance.make(space: space)
        get "/v3/service_instances/#{upsi.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(404)
      end
    end
  end

  describe 'POST /v3/service_instances' do
    let(:api_call) { lambda { |user_headers| post '/v3/service_instances', request_body.to_json, user_headers } }
    let(:type) { 'user-provided' }
    let(:space_guid) { space.guid }
    let(:request_body) {
      {
        type: type,
        relationships: {
          space: {
            data: {
              guid: space_guid
            }
          }
        }
      }
    }

    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end

    context 'when service_instance_creation flag is disabled' do
      before do
        VCAP::CloudController::FeatureFlag.create(name: 'service_instance_creation', enabled: false)
      end

      it 'makes non_admins unable to create any type of service' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include({ 'detail' => 'Feature Disabled: service_instance_creation' })
        )
      end

      it 'does not impact admins ability create services' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(200)
      end
    end

    context 'when the target organization is suspended' do
      before do
        org.status = VCAP::CloudController::Organization::SUSPENDED
        org.save
      end

      it 'makes non-admins unable to create any type of service' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include({ 'detail' => 'You are not authorized to perform the requested action' })
        )
      end

      it 'does not impact admins ability to create services' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(200)
      end
    end

    context 'when the request body is invalid' do
      let(:request_body) { { type: 'foo' } }

      it 'returns a bad request' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(
          include({ 'detail' => include("Type must be one of 'managed', 'user-provided'") })
        )
      end
    end
  end

  def create_managed_json(instance, labels: {})
    {
      guid: instance.guid,
      name: instance.name,
      created_at: iso8601,
      updated_at: iso8601,
      type: 'managed',
      dashboard_url: nil,
      last_operation: {},
      maintenance_info: {},
      upgrade_available: false,
      tags: [],
      metadata: {
        labels: labels,
        annotations: {},
      },
      relationships: {
        space: {
          data: {
            guid: instance.space.guid
          }
        },
        service_plan: {
          data: {
            guid: instance.service_plan.guid,
            name: instance.service_plan.name
          }
        }
      },
      links: {
        self: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}"
        },
        space: {
          href: "#{link_prefix}/v3/spaces/#{instance.space.guid}"
        },
        service_plan: {
          href: "#{link_prefix}/v3/service_plans/#{instance.service_plan.guid}"
        },
        parameters: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}/parameters"
        },
      },
    }
  end

  def create_user_provided_json(instance, labels: {})
    {
      guid: instance.guid,
      name: instance.name,
      created_at: iso8601,
      updated_at: iso8601,
      type: 'user-provided',
      syslog_drain_url: instance.syslog_drain_url,
      route_service_url: nil,
      tags: [],
      metadata: {
        labels: labels,
        annotations: {},
      },
      relationships: {
        space: {
          data: {
            guid: instance.space.guid
          }
        }
      },
      links: {
        self: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}"
        },
        space: {
          href: "#{link_prefix}/v3/spaces/#{instance.space.guid}"
        },
        credentials: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}/credentials"
        }
      },
    }
  end

  describe 'unrefactored' do
    let(:user_email) { 'user@email.example.com' }
    let(:user_name) { 'username' }
    let(:user) { VCAP::CloudController::User.make }
    let(:user_header) { headers_for(user) }
    let(:admin_header) { admin_headers_for(user, email: user_email, user_name: user_name) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:another_space) { VCAP::CloudController::Space.make }
    let(:target_space) { VCAP::CloudController::Space.make }
    let(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: false, error_message: nil) }
    let!(:annotations) { VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value') }
    let!(:service_instance1) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'rabbitmq') }
    let!(:service_instance2) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'redis') }
    let!(:service_instance3) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space, name: 'mysql') }

    describe 'GET /v3/service_instances/:guid/relationships/shared_spaces' do
      before do
        share_request = {
          'data' => [
            { 'guid' => target_space.guid }
          ]
        }

        enable_feature_flag!
        post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header
        expect(last_response.status).to eq(200)

        disable_feature_flag!
      end

      it 'returns a list of space guids where the service instance is shared to' do
        set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)

        get "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", nil, user_header

        expect(last_response.status).to eq(200)

        expected_response = {
          'data' => [
            { 'guid' => target_space.guid }
          ],
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces" },
          }
        }

        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

    describe 'POST /v3/service_instances/:guid/relationships/shared_spaces' do
      before do
        VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)
      end

      it 'shares the service instance with the target space' do
        share_request = {
          'data' => [
            { 'guid' => target_space.guid }
          ]
        }

        post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(200)

        expected_response = {
          'data' => [
            { 'guid' => target_space.guid }
          ],
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces" },
          }
        }

        expect(parsed_response).to be_a_response_like(expected_response)

        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
          type: 'audit.service_instance.share',
          actor: user.guid,
          actor_type: 'user',
          actor_name: user_email,
          actor_username: user_name,
          actee: service_instance1.guid,
          actee_type: 'service_instance',
          actee_name: service_instance1.name,
          space_guid: space.guid,
          organization_guid: space.organization.guid
        })
        expect(event.metadata['target_space_guids']).to eq([target_space.guid])
      end
    end

    describe 'PATCH /v3/service_instances/:guid' do
      before do
        service_instance1.annotation_ids = [annotations.id]
      end
      let(:metadata_request) do
        {
          "metadata": {
            "labels": {
              "potato": 'yam',
              "style": 'baked'
            },
            "annotations": {
              "potato": 'idaho',
              "style": 'mashed',
              "pre.fix/to_delete": nil
            }
          }
        }
      end

      it 'updates metadata on a service instance' do
        patch "/v3/service_instances/#{service_instance1.guid}", metadata_request.to_json, admin_header

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(200)

        expect(parsed_response).to be_a_response_like(
          {
            'guid' => service_instance1.guid,
            'name' => service_instance1.name,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'dashboard_url' => nil,
            'last_operation' => {},
            'maintenance_info' => {},
            'tags' => [],
            'type' => 'managed',
            'upgrade_available' => false,
            'relationships' => {
              'space' => {
                'data' => {
                  'guid' => service_instance1.space.guid
                }
              },
              'service_plan' => {
                'data' => {
                  'guid' => service_instance1.service_plan.guid,
                  'name' => service_instance1.service_plan.name
                }
              }
            },
            'links' => {
              'space' => {
                'href' => "#{link_prefix}/v3/spaces/#{service_instance1.space.guid}"
              },
              'service_plan' => {
                'href' => "#{link_prefix}/v3/service_plans/#{service_instance1.service_plan.guid}"
              },
              'self' => {
                'href' => "#{link_prefix}/v3/service_instances/#{service_instance1.guid}"
              },
              'parameters' => {
                'href' => "#{link_prefix}/v3/service_instances/#{service_instance1.guid}/parameters"
              }
            },
            'metadata' => {
              'labels' => {
                'potato' => 'yam',
                'style' => 'baked'
              },
              'annotations' => {
                'potato' => 'idaho',
                'style' => 'mashed'
              }
            }
          }
        )
      end
    end

    describe 'DELETE /v3/service_instances/:guid/relationships/shared_spaces/:space-guid' do
      before do
        allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
          FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
        end

        share_request = {
          'data' => [
            { 'guid' => target_space.guid }
          ]
        }

        enable_feature_flag!
        post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header
        expect(last_response.status).to eq(200)

        disable_feature_flag!
      end

      it 'unshares the service instance from the target space' do
        delete "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces/#{target_space.guid}", nil, admin_header
        expect(last_response.status).to eq(204)

        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
          type: 'audit.service_instance.unshare',
          actor: user.guid,
          actor_type: 'user',
          actor_name: user_email,
          actor_username: user_name,
          actee: service_instance1.guid,
          actee_type: 'service_instance',
          actee_name: service_instance1.name,
          space_guid: space.guid,
          organization_guid: space.organization.guid
        })
        expect(event.metadata['target_space_guid']).to eq(target_space.guid)
      end

      it 'deletes associated bindings in target space when service instance is unshared' do
        process = VCAP::CloudController::ProcessModelFactory.make(diego: false, space: target_space)

        enable_feature_flag!
        service_binding = VCAP::CloudController::ServiceBinding.make(service_instance: service_instance1, app: process.app, credentials: { secret: 'key' })
        disable_feature_flag!

        get "/v2/service_bindings/#{service_binding.guid}", nil, admin_header
        expect(last_response.status).to eq(200)

        delete "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces/#{target_space.guid}", nil, admin_header
        expect(last_response.status).to eq(204)

        get "/v2/service_bindings/#{service_binding.guid}", nil, admin_header
        expect(last_response.status).to eq(404)
      end
    end

    def enable_feature_flag!
      feature_flag.enabled = true
      feature_flag.save
    end

    def disable_feature_flag!
      feature_flag.enabled = false
      feature_flag.save
    end
  end
end
