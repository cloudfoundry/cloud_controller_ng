require 'spec_helper'

RSpec.describe 'ServiceInstances' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
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

        it 'lists all service_instances' do
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
                'name'                 => service_instance.name,
                'credentials'          => service_instance.credentials,
                'service_guid'         => service_instance.service.guid,
                'service_plan_guid'    => service_plan.guid,
                'space_guid'           => service_instance.space_guid,
                'gateway_data'         => service_instance.gateway_data,
                'dashboard_url'        => service_instance.dashboard_url,
                'type'                 => service_instance.type,
                'last_operation'       => service_instance.last_operation,
                'tags'                 => service_instance.tags,
                'space_url'            => "/v2/spaces/#{space.guid}",
                'service_url'          => "/v2/services/#{service_instance.service.guid}",
                'service_plan_url'     => "/v2/service_plans/#{service_plan.guid}",
                'service_bindings_url' => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'     => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'           => "/v2/service_instances/#{service_instance.guid}/routes",
                'shared_from_url'      => "/v2/service_instances/#{service_instance.guid}/shared_from",
                'shared_to_url'        => "/v2/service_instances/#{service_instance.guid}/shared_to",
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
                'name'                 => service_instance.name,
                'credentials'          => service_instance.credentials,
                'service_guid'         => service_instance.service.guid,
                'service_plan_guid'    => service_plan.guid,
                'space_guid'           => service_instance.space_guid,
                'gateway_data'         => service_instance.gateway_data,
                'dashboard_url'        => service_instance.dashboard_url,
                'type'                 => service_instance.type,
                'last_operation'       => service_instance.last_operation,
                'tags'                 => service_instance.tags,
                'space_url'            => "/v2/spaces/#{space.guid}",
                'service_url'          => "/v2/services/#{service_instance.service.guid}",
                'service_bindings_url' => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'     => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'           => "/v2/service_instances/#{service_instance.guid}/routes",
                'shared_from_url'      => "/v2/service_instances/#{service_instance.guid}/shared_from",
                'shared_to_url'        => "/v2/service_instances/#{service_instance.guid}/shared_to",
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
                'name'                 => service_instance.name,
                'credentials'          => service_instance.credentials,
                'service_guid'         => service_instance.service.guid,
                'service_plan_guid'    => service_plan.guid,
                'space_guid'           => service_instance.space_guid,
                'gateway_data'         => service_instance.gateway_data,
                'dashboard_url'        => service_instance.dashboard_url,
                'type'                 => service_instance.type,
                'last_operation'       => service_instance.last_operation,
                'tags'                 => service_instance.tags,
                'space_url'            => "/v2/spaces/#{space.guid}",
                'service_url'          => "/v2/services/#{service_instance.service.guid}",
                'service_bindings_url' => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'     => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'           => "/v2/service_instances/#{service_instance.guid}/routes",
                'shared_from_url'      => "/v2/service_instances/#{service_instance.guid}/shared_from",
                'shared_to_url'        => "/v2/service_instances/#{service_instance.guid}/shared_to",
              }
            }
          )
        end
      end
    end
  end

  describe 'GET /v2/service_instances/:service_instance_guid/shared_from' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }

    before do
      service_instance.add_shared_space(VCAP::CloudController::Space.make)
    end

    it 'returns data about the source space and org' do
      get "v2/service_instances/#{service_instance.guid}/shared_from", nil, admin_headers

      expect(last_response.status).to eq(200), last_response.body

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like({
        'space_name' => space.name,
        'organization_name' => space.organization.name
      })
    end

    context 'when the user is a member of the space where a service instance has been shared to' do
      let(:other_space) { VCAP::CloudController::Space.make }
      let(:other_user) { make_developer_for_space(other_space) }
      let(:req_body) do
        {
          data: [
            { guid: other_space.guid }
          ]
        }.to_json
      end

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)

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
          'space_name' => space.name,
          'organization_name' => space.organization.name
        })
      end
    end
  end

  describe 'GET /v2/service_instances/:service_instance_guid/shared_to' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:space1) { VCAP::CloudController::Space.make }
    let(:space2) { VCAP::CloudController::Space.make }

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
              'space_name' => space1.name,
              'organization_name' => space1.organization.name,
              'bound_app_count' => 0
            },
            {
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
    let(:originating_space) { VCAP::CloudController::Space.make }
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
end
