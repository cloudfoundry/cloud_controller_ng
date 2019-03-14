require 'spec_helper'

RSpec.describe 'ServiceInstances' do
  let(:user) { FactoryBot.create(:user) }
  let(:space) { FactoryBot.create(:space) }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'POST /v2/service_instances' do
    let(:service_plan) { VCAP::CloudController::ServicePlan.make }

    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
        FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
      end
    end

    it 'creates a service instance' do
      post_params = MultiJson.dump({
        name:              'awesome-service-instance',
        space_guid:        space.guid,
        service_plan_guid: service_plan.guid,
        parameters:        { 'KEY' => 'val' },
        tags:              ['no-sql', 'georeplicated'],
      })

      post '/v2/service_instances', post_params, admin_headers

      service_instance = VCAP::CloudController::ManagedServiceInstance.last
      expect(last_response).to have_status_code(201)
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid'       => service_instance.guid,
            'url'        => "/v2/service_instances/#{service_instance.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601 },
          'entity' => {
            'name'                 => 'awesome-service-instance',
            'credentials'          => service_instance.credentials,
            'service_guid'         => service_plan.service.guid,
            'service_plan_guid'    => service_plan.guid,
            'space_guid'           => space.guid,
            'gateway_data'         => service_instance.gateway_data,
            'dashboard_url'        => service_instance.dashboard_url,
            'type'                 => 'managed_service_instance',
            'last_operation' => {
              'type'        => 'create',
              'state'       => 'succeeded',
              'description' => '',
              'updated_at'  => iso8601,
              'created_at'  => iso8601
            },
            'tags'                            => ['no-sql', 'georeplicated'],
            'space_url'                       => "/v2/spaces/#{space.guid}",
            'service_url'                     => "/v2/services/#{service_instance.service.guid}",
            'service_plan_url'                => "/v2/service_plans/#{service_plan.guid}",
            'service_bindings_url'            => "/v2/service_instances/#{service_instance.guid}/service_bindings",
            'service_keys_url'                => "/v2/service_instances/#{service_instance.guid}/service_keys",
            'routes_url'                      => "/v2/service_instances/#{service_instance.guid}/routes",
            'shared_from_url'                 => "/v2/service_instances/#{service_instance.guid}/shared_from",
            'shared_to_url'                   => "/v2/service_instances/#{service_instance.guid}/shared_to",
            'service_instance_parameters_url' => "/v2/service_instances/#{service_instance.guid}/parameters",
          }
        }
      )
    end
  end

  describe 'PUT /v2/service_instances/:guid' do
    let(:service) { VCAP::CloudController::Service.make(plan_updateable: true) }
    let(:old_service_plan) { VCAP::CloudController::ServicePlan.make(service: service) }
    let(:new_service_plan) { VCAP::CloudController::ServicePlan.make(service: service) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: old_service_plan) }

    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
        FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
      end
    end

    it 'updates a service instance' do
      put_params = MultiJson.dump({
        name:              'awesome-service-instance',
        space_guid:        space.guid,
        service_plan_guid: new_service_plan.guid,
        parameters:        { 'KEY' => 'val' },
        tags:              ['no-sql', 'georeplicated'],
      })

      put "/v2/service_instances/#{service_instance.guid}", put_params, admin_headers

      service_instance = VCAP::CloudController::ManagedServiceInstance.last
      expect(last_response).to have_status_code(201)
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid'       => service_instance.guid,
            'url'        => "/v2/service_instances/#{service_instance.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601 },
          'entity' => {
            'name'                 => 'awesome-service-instance',
            'credentials'          => service_instance.credentials,
            'service_guid'         => new_service_plan.service.guid,
            'service_plan_guid'    => new_service_plan.guid,
            'space_guid'           => space.guid,
            'gateway_data'         => service_instance.gateway_data,
            'dashboard_url'        => service_instance.dashboard_url,
            'type'                 => 'managed_service_instance',
            'last_operation' => {
              'type'        => 'update',
              'description' => '',
              'state'       => 'succeeded',
              'updated_at'  => iso8601,
              'created_at'  => iso8601
            },
            'tags'                            => ['no-sql', 'georeplicated'],
            'space_url'                       => "/v2/spaces/#{space.guid}",
            'service_url'                     => "/v2/services/#{service_instance.service.guid}",
            'service_plan_url'                => "/v2/service_plans/#{new_service_plan.guid}",
            'service_bindings_url'            => "/v2/service_instances/#{service_instance.guid}/service_bindings",
            'service_keys_url'                => "/v2/service_instances/#{service_instance.guid}/service_keys",
            'routes_url'                      => "/v2/service_instances/#{service_instance.guid}/routes",
            'shared_from_url'                 => "/v2/service_instances/#{service_instance.guid}/shared_from",
            'shared_to_url'                   => "/v2/service_instances/#{service_instance.guid}/shared_to",
            'service_instance_parameters_url' => "/v2/service_instances/#{service_instance.guid}/parameters",
          }
        }
      )
    end

    context 'the user is space_developer' do
      context 'current plan is not accessible' do
        let(:old_service_plan) { VCAP::CloudController::ServicePlan.make(service: service, public: false) }
        it 'allows updates for name and tags' do
          put_params = MultiJson.dump({
            name:              'awesome-service-instance',
            space_guid:        space.guid,
            tags:              ['no-sql', 'georeplicated'],
          })

          put "/v2/service_instances/#{service_instance.guid}", put_params, headers_for(user)

          service_instance = VCAP::CloudController::ManagedServiceInstance.last
          expect(last_response).to have_status_code(201)
          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response).to be_a_response_like(
            {
              'metadata' => {
                'guid'       => service_instance.guid,
                'url'        => "/v2/service_instances/#{service_instance.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601 },
                'entity' => {
                  'name'                 => 'awesome-service-instance',
                  'credentials'          => service_instance.credentials,
                  'service_guid'         => old_service_plan.service.guid,
                  'service_plan_guid'    => old_service_plan.guid,
                  'space_guid'           => space.guid,
                  'gateway_data'         => service_instance.gateway_data,
                  'dashboard_url'        => service_instance.dashboard_url,
                  'type'                 => 'managed_service_instance',
                  'last_operation' => {
                    'type'        => 'update',
                    'description' => nil,
                    'state'       => 'succeeded',
                    'updated_at'  => iso8601,
                    'created_at'  => iso8601
                  },
                  'tags'                            => ['no-sql', 'georeplicated'],
                  'space_url'                       => "/v2/spaces/#{space.guid}",
                  'service_url'                     => "/v2/services/#{service_instance.service.guid}",
                  'service_bindings_url'            => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                  'service_keys_url'                => "/v2/service_instances/#{service_instance.guid}/service_keys",
                  'routes_url'                      => "/v2/service_instances/#{service_instance.guid}/routes",
                  'shared_from_url'                 => "/v2/service_instances/#{service_instance.guid}/shared_from",
                  'shared_to_url'                   => "/v2/service_instances/#{service_instance.guid}/shared_to",
                  'service_instance_parameters_url' => "/v2/service_instances/#{service_instance.guid}/parameters",
                }
            }
          )
        end

        it 'does not allow updates for parameters' do
          put_params = MultiJson.dump({
            space_guid:        space.guid,
            parameters:        { 'KEY' => 'val' },
          })

          put "/v2/service_instances/#{service_instance.guid}", put_params, headers_for(user)

          expect(last_response).to have_status_code(403)
        end
      end

      context 'new plan is not accessible' do
        let(:new_service_plan) { VCAP::CloudController::ServicePlan.make(service: service, public: false) }

        it 'does not allow updates' do
          put_params = MultiJson.dump({
            name:              'awesome-service-instance',
            service_plan_guid: new_service_plan.guid,
            space_guid:        space.guid,
            parameters:        { 'KEY' => 'val' },
            tags:              ['no-sql', 'georeplicated'],
          })

          put "/v2/service_instances/#{service_instance.guid}", put_params, headers_for(user)

          expect(last_response).to have_status_code(403)
        end
      end
    end
  end

  describe 'GET /v2/service_instances/:service_instance_guid' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(active: false) }

    before do
      service_instance.dashboard_url   = 'someurl.com'
      service_instance.service_plan_id = service_plan.id
      service_instance.save
    end

    context 'with a managed service instance' do
      context 'admin' do
        before do
          set_current_user_as_admin
        end

        it 'returns data about the given service instance' do
          get "v2/service_instances/#{service_instance.guid}", nil, admin_headers

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response).to be_a_response_like(
            {
              'metadata' => {
                'guid'       => service_instance.guid,
                'url'        => "/v2/service_instances/#{service_instance.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601 },
              'entity'   => {
                'name'                            => service_instance.name,
                'credentials'                     => service_instance.credentials,
                'service_guid'                    => service_instance.service.guid,
                'service_plan_guid'               => service_plan.guid,
                'space_guid'                      => service_instance.space_guid,
                'gateway_data'                    => service_instance.gateway_data,
                'dashboard_url'                   => service_instance.dashboard_url,
                'type'                            => service_instance.type,
                'last_operation'                  => service_instance.last_operation,
                'tags'                            => service_instance.tags,
                'space_url'                       => "/v2/spaces/#{space.guid}",
                'service_url'                     => "/v2/services/#{service_instance.service.guid}",
                'service_plan_url'                => "/v2/service_plans/#{service_plan.guid}",
                'service_bindings_url'            => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'                => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'                      => "/v2/service_instances/#{service_instance.guid}/routes",
                'shared_from_url'                 => "/v2/service_instances/#{service_instance.guid}/shared_from",
                'shared_to_url'                   => "/v2/service_instances/#{service_instance.guid}/shared_to",
                'service_instance_parameters_url' => "/v2/service_instances/#{service_instance.guid}/parameters",
              }
            }
          )
        end
      end

      context 'space developer' do
        let(:user) { make_developer_for_space(space) }

        before do
          set_current_user(user)
        end

        it 'returns service_plan_guid in the response' do
          get "v2/service_instances/#{service_instance.guid}", nil, headers_for(user)

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response).to be_a_response_like(
            {
              'metadata' => {
                'guid'       => service_instance.guid,
                'url'        => "/v2/service_instances/#{service_instance.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601 },
              'entity'   => {
                'name'                            => service_instance.name,
                'credentials'                     => service_instance.credentials,
                'service_guid'                    => service_instance.service.guid,
                'service_plan_guid'               => service_plan.guid,
                'space_guid'                      => service_instance.space_guid,
                'gateway_data'                    => service_instance.gateway_data,
                'dashboard_url'                   => service_instance.dashboard_url,
                'type'                            => service_instance.type,
                'last_operation'                  => service_instance.last_operation,
                'tags'                            => service_instance.tags,
                'space_url'                       => "/v2/spaces/#{space.guid}",
                'service_url'                     => "/v2/services/#{service_instance.service.guid}",
                'service_bindings_url'            => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'                => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'                      => "/v2/service_instances/#{service_instance.guid}/routes",
                'shared_from_url'                 => "/v2/service_instances/#{service_instance.guid}/shared_from",
                'shared_to_url'                   => "/v2/service_instances/#{service_instance.guid}/shared_to",
                'service_instance_parameters_url' => "/v2/service_instances/#{service_instance.guid}/parameters",
              }
            }
          )
        end
      end

      context 'space manager' do
        let(:user) { make_manager_for_space(space) }

        before do
          set_current_user(user)
        end
        it 'returns the service_plan_guid in the response' do
          get "v2/service_instances/#{service_instance.guid}", nil, headers_for(user)

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response).to be_a_response_like(
            {
              'metadata' => {
                'guid'       => service_instance.guid,
                'url'        => "/v2/service_instances/#{service_instance.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601 },
              'entity'   => {
                'name'                            => service_instance.name,
                'credentials'                     => service_instance.credentials,
                'service_guid'                    => service_instance.service.guid,
                'service_plan_guid'               => service_plan.guid,
                'space_guid'                      => service_instance.space_guid,
                'gateway_data'                    => service_instance.gateway_data,
                'dashboard_url'                   => service_instance.dashboard_url,
                'type'                            => service_instance.type,
                'last_operation'                  => service_instance.last_operation,
                'tags'                            => service_instance.tags,
                'space_url'                       => "/v2/spaces/#{space.guid}",
                'service_url'                     => "/v2/services/#{service_instance.service.guid}",
                'service_bindings_url'            => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'                => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'                      => "/v2/service_instances/#{service_instance.guid}/routes",
                'shared_from_url'                 => "/v2/service_instances/#{service_instance.guid}/shared_from",
                'shared_to_url'                   => "/v2/service_instances/#{service_instance.guid}/shared_to",
                'service_instance_parameters_url' => "/v2/service_instances/#{service_instance.guid}/parameters",
              }
            }
          )
        end
      end
    end
  end

  describe 'GET /v2/service_instances/:service_instance_guid/parameters' do
    let(:service) { VCAP::CloudController::Service.make(instances_retrievable: true) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }

    context 'with a managed service instance' do
      before do
        set_current_user_as_admin

        allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
          fb = FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
          fb.parameters = {
            parameters: {
              top_level_param: {
                nested_param: true,
              },
              another_param: 'some-value',
            }
          }
          fb
        end
      end

      it 'returns all parameters of the service instance' do
        get "v2/service_instances/#{service_instance.guid}/parameters", nil, admin_headers

        expect(last_response.status).to eq(200)

        parsed_response = last_response.body
        expect(MultiJson.load(parsed_response)).to be_a_response_like(
          {
            'top_level_param' => {
              'nested_param' => true,
            },
            'another_param' => 'some-value',
          }
        )
      end
    end
  end

  describe 'GET /v2/service_instances/:service_instance_guid/routes/:route_guid/parameters' do
    let(:service) { VCAP::CloudController::Service.make(:routing, bindings_retrievable: true) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let!(:route_binding) { VCAP::CloudController::RouteBinding.make(route: route, service_instance: service_instance) }

    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
        fb = FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
        fb.parameters = {
          parameters: {
            top_level_param: {
              nested_param: true,
            },
            another_param: 'some-value',
          }
        }
        fb
      end
    end

    it 'returns all parameters of the route binding' do
      get "v2/service_instances/#{service_instance.guid}/routes/#{route.guid}/parameters", nil, headers_for(user)

      expect(last_response).to have_status_code(200)

      parsed_response = last_response.body
      expect(MultiJson.load(parsed_response)).to be_a_response_like(
        {
          'top_level_param' => {
            'nested_param' => true,
          },
          'another_param' => 'some-value',
        }
      )
    end
  end

  describe 'GET /v2/service_instances/:service_instance_guid/shared_from' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }

    before do
      service_instance.add_shared_space(FactoryBot.create(:space))
    end

    it 'returns data about the source space and org' do
      get "v2/service_instances/#{service_instance.guid}/shared_from", nil, admin_headers

      expect(last_response.status).to eq(200), last_response.body

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like({
        'space_guid' => space.guid,
        'space_name' => space.name,
        'organization_name' => space.organization.name
      })
    end

    context 'when the user is a member of the space where a service instance has been shared to' do
      let(:other_space) { FactoryBot.create(:space) }
      let(:other_user) { make_developer_for_space(other_space) }
      let(:req_body) do
        {
          data: [
            { guid: other_space.guid }
          ]
        }.to_json
      end

      before do
        FactoryBot.create(:feature_flag, name: 'service_instance_sharing', enabled: true, error_message: nil)

        other_space.organization.add_user(user)
        other_space.add_developer(user)

        post "v3/service_instances/#{service_instance.guid}/relationships/shared_spaces", req_body, headers_for(user)
        expect(last_response.status).to eq(200)
      end

      it 'returns data about the source space and org' do
        get "v2/service_instances/#{service_instance.guid}/shared_from", nil, headers_for(other_user)

        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like({
          'space_guid' => space.guid,
          'space_name' => space.name,
          'organization_name' => space.organization.name
        })
      end
    end
  end

  describe 'GET /v2/service_instances/:service_instance_guid/shared_to' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:space1) { FactoryBot.create(:space) }
    let(:space2) { FactoryBot.create(:space) }

    before do
      service_instance.add_shared_space(space1)
      service_instance.add_shared_space(space2)
    end

    it 'returns data about the source space, org, and bound_app_count' do
      get "v2/service_instances/#{service_instance.guid}/shared_to", nil, admin_headers

      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'total_results' => 2,
          'total_pages' => 1,
          'prev_url' => nil,
          'next_url' => nil,
          'resources' => [
            {
              'space_guid' => space1.guid,
              'space_name' => space1.name,
              'organization_name' => space1.organization.name,
              'bound_app_count' => 0
            },
            {
              'space_guid' => space2.guid,
              'space_name' => space2.name,
              'organization_name' => space2.organization.name,
              'bound_app_count' => 0
            }
          ]
        }
      )
    end
  end

  describe 'DELETE /v2/service_instance/:guid' do
    let(:originating_space) { FactoryBot.create(:space) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: originating_space) }

    context 'when the service instance has been shared' do
      before do
        allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
          FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
        end

        set_current_user_as_admin
        service_instance.add_shared_space(space)
      end

      it 'fails with an appropriate response' do
        delete "v2/service_instances/#{service_instance.guid}", nil, admin_headers

        expect(last_response.status).to eq(422)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['description']).to eq 'Service instances must be unshared before they can be deleted. ' \
          "Unsharing #{service_instance.name} will automatically delete any bindings " \
          'that have been made to applications in other spaces.'
        expect(parsed_response['error_code']).to eq 'CF-ServiceInstanceDeletionSharesExists'
        expect(parsed_response['code']).to eq 390002
      end
    end
  end

  describe 'POST /v2/user_provided_service_instances' do
    it 'creates a user-provided service instance' do
      post_params = MultiJson.dump({
        name:              'awesome-service-instance',
        space_guid:        space.guid,
        tags:              ['no-sql', 'georeplicated'],
        syslog_drain_url:  'syslog://example.com',
        credentials:       { 'somekey': 'somevalue' },
        route_service_url: 'https://logger.example.com',
      })

      post '/v2/user_provided_service_instances', post_params, admin_headers

      service_instance = VCAP::CloudController::UserProvidedServiceInstance.last
      expect(last_response).to have_status_code(201)
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid'       => service_instance.guid,
            'url'        => "/v2/user_provided_service_instances/#{service_instance.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601 },
          'entity' => {
            'name'                 => 'awesome-service-instance',
            'credentials'          => { 'somekey' => 'somevalue' },
            'space_guid'           => space.guid,
            'type'                 => 'user_provided_service_instance',
            'tags'                 => ['no-sql', 'georeplicated'],
            'space_url'            => "/v2/spaces/#{space.guid}",
            'service_bindings_url' => "/v2/user_provided_service_instances/#{service_instance.guid}/service_bindings",
            'routes_url'           => "/v2/user_provided_service_instances/#{service_instance.guid}/routes",
            'syslog_drain_url'     => 'syslog://example.com',
            'route_service_url'    => 'https://logger.example.com',
          }
        }
      )
    end
  end

  describe 'PUT /v2/user_provided_service_instances/:guid' do
    let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }

    it 'updates the user-provided service instance' do
      put_params = MultiJson.dump({
        name:              'awesome-service-instance',
        space_guid:        space.guid,
        tags:              ['no-sql', 'georeplicated'],
        syslog_drain_url:  'syslog://example.com',
        credentials:       { 'somekey': 'somevalue' },
        route_service_url: 'https://logger.example.com',
      })

      put "/v2/user_provided_service_instances/#{service_instance.guid}", put_params, admin_headers

      expect(last_response).to have_status_code(201)
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid'       => service_instance.guid,
            'url'        => "/v2/user_provided_service_instances/#{service_instance.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601 },
          'entity' => {
            'name'                 => 'awesome-service-instance',
            'credentials'          => { 'somekey' => 'somevalue' },
            'space_guid'           => space.guid,
            'type'                 => 'user_provided_service_instance',
            'tags'                 => ['no-sql', 'georeplicated'],
            'space_url'            => "/v2/spaces/#{space.guid}",
            'service_bindings_url' => "/v2/user_provided_service_instances/#{service_instance.guid}/service_bindings",
            'routes_url'           => "/v2/user_provided_service_instances/#{service_instance.guid}/routes",
            'syslog_drain_url'     => 'syslog://example.com',
            'route_service_url'    => 'https://logger.example.com',
          }
        }
      )
    end
  end
end
