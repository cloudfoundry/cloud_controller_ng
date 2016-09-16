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
                'service_plan_guid'    => service_plan.guid,
                'space_guid'           => service_instance.space_guid,
                'gateway_data'         => service_instance.gateway_data,
                'dashboard_url'        => service_instance.dashboard_url,
                'type'                 => service_instance.type,
                'last_operation'       => service_instance.last_operation,
                'tags'                 => service_instance.tags,
                'space_url'            => "/v2/spaces/#{space.guid}",
                'service_plan_url'     => "/v2/service_plans/#{service_plan.guid}",
                'service_bindings_url' => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'     => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'           => "/v2/service_instances/#{service_instance.guid}/routes"
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
                'service_plan_guid'    => service_plan.guid,
                'space_guid'           => service_instance.space_guid,
                'gateway_data'         => service_instance.gateway_data,
                'dashboard_url'        => service_instance.dashboard_url,
                'type'                 => service_instance.type,
                'last_operation'       => service_instance.last_operation,
                'tags'                 => service_instance.tags,
                'space_url'            => "/v2/spaces/#{space.guid}",
                'service_bindings_url' => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'     => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'           => "/v2/service_instances/#{service_instance.guid}/routes"
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
                'service_plan_guid'    => service_plan.guid,
                'space_guid'           => service_instance.space_guid,
                'gateway_data'         => service_instance.gateway_data,
                'dashboard_url'        => service_instance.dashboard_url,
                'type'                 => service_instance.type,
                'last_operation'       => service_instance.last_operation,
                'tags'                 => service_instance.tags,
                'space_url'            => "/v2/spaces/#{space.guid}",
                'service_bindings_url' => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'     => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'           => "/v2/service_instances/#{service_instance.guid}/routes"
              }
            }
          )
        end
      end
    end
  end
end
