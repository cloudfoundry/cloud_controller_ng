require 'spec_helper'

RSpec.describe 'Spaces' do
  let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
  let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make }
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }

  describe 'POST /v2/spaces' do
    let(:opts) do
      MultiJson.dump({
        'name' => 'space_name',
        'organization_guid' => org.guid,
        'isolation_segment_guid' => isolation_segment.guid
      })
    end

    context 'as admin' do
      context 'and the organization has an isolation segment' do
        before do
          assigner.assign(isolation_segment, [org])
        end

        it 'creates a space and associates the isolation segment' do
          post '/v2/spaces', opts, admin_headers_for(user)

          expect(last_response.status).to eq(201)
          parsed_response = MultiJson.load(last_response.body)

          space = VCAP::CloudController::Space.last

          expect(parsed_response).to be_a_response_like({
            'metadata' => {
              'guid' => space.guid,
              'url' => "/v2/spaces/#{space.guid}",
              'created_at' => iso8601,
              'updated_at' => iso8601
            },
            'entity' => {
              'name' => space.name,
              'organization_guid' => org.guid,
              'space_quota_definition_guid' => nil,
              'isolation_segment_guid' => isolation_segment.guid,
              'allow_ssh' => true,
              'organization_url' => "/v2/organizations/#{org.guid}",
              'isolation_segment_url' => "/v3/isolation_segments/#{isolation_segment.guid}",
              'developers_url' => "/v2/spaces/#{space.guid}/developers",
              'managers_url' => "/v2/spaces/#{space.guid}/managers",
              'auditors_url' => "/v2/spaces/#{space.guid}/auditors",
              'apps_url' => "/v2/spaces/#{space.guid}/apps",
              'routes_url' => "/v2/spaces/#{space.guid}/routes",
              'domains_url' => "/v2/spaces/#{space.guid}/domains",
              'service_instances_url' => "/v2/spaces/#{space.guid}/service_instances",
              'app_events_url' => "/v2/spaces/#{space.guid}/app_events",
              'events_url' => "/v2/spaces/#{space.guid}/events",
              'security_groups_url' => "/v2/spaces/#{space.guid}/security_groups",
              'staging_security_groups_url' => "/v2/spaces/#{space.guid}/staging_security_groups"
            }
          })
        end
      end
    end
  end

  describe 'GET /v2/spaces' do
    context 'when a isolation segment is associated to the space' do
      let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }

      before do
        assigner.assign(isolation_segment, [org])
        isolation_segment.add_space(space)

        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'lists the isolation segment for SpaceDevelopers' do
        get '/v2/spaces', {}, headers_for(user)

        expect(last_response.status).to eq(200)
        parsed_response = MultiJson.load(last_response.body)

        expect(parsed_response).to be_a_response_like({
          'total_results' => 1,
          'total_pages'   => 1,
          'prev_url'      => nil,
          'next_url'      => nil,
          'resources'     => [{
            'metadata' => {
              'guid' => space.guid,
              'url' => "/v2/spaces/#{space.guid}",
              'created_at' => iso8601,
              'updated_at' => iso8601,
            },
            'entity' => {
              'name' => space.name,
              'organization_guid' => org.guid,
              'space_quota_definition_guid' => nil,
              'isolation_segment_guid' => isolation_segment.guid,
              'allow_ssh' => true,
              'organization_url' => "/v2/organizations/#{org.guid}",
              'isolation_segment_url' => "/v3/isolation_segments/#{isolation_segment.guid}",
              'developers_url' => "/v2/spaces/#{space.guid}/developers",
              'managers_url' => "/v2/spaces/#{space.guid}/managers",
              'auditors_url' => "/v2/spaces/#{space.guid}/auditors",
              'apps_url' => "/v2/spaces/#{space.guid}/apps",
              'routes_url' => "/v2/spaces/#{space.guid}/routes",
              'domains_url' => "/v2/spaces/#{space.guid}/domains",
              'service_instances_url' => "/v2/spaces/#{space.guid}/service_instances",
              'app_events_url' => "/v2/spaces/#{space.guid}/app_events",
              'events_url' => "/v2/spaces/#{space.guid}/events",
              'security_groups_url' => "/v2/spaces/#{space.guid}/security_groups",
              'staging_security_groups_url' => "/v2/spaces/#{space.guid}/staging_security_groups"
            }
          }]
        })
      end
    end
  end

  describe 'GET /v2/spaces/:guid' do
    context 'when a isolation segment is associated to the space' do
      let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }

      before do
        assigner.assign(isolation_segment, [org])
        isolation_segment.add_space(space)

        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'lists the isolation segment for SpaceDevelopers' do
        get "/v2/spaces/#{space.guid}", {}, headers_for(user)

        expect(last_response.status).to eq(200)
        parsed_response = MultiJson.load(last_response.body)

        expect(parsed_response).to be_a_response_like({
          'metadata' => {
            'guid' => space.guid,
            'url' => "/v2/spaces/#{space.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601,
          },
          'entity' => {
            'name' => space.name,
            'organization_guid' => org.guid,
            'space_quota_definition_guid' => nil,
            'isolation_segment_guid' => isolation_segment.guid,
            'allow_ssh' => true,
            'organization_url' => "/v2/organizations/#{org.guid}",
            'isolation_segment_url' => "/v3/isolation_segments/#{isolation_segment.guid}",
            'developers_url' => "/v2/spaces/#{space.guid}/developers",
            'managers_url' => "/v2/spaces/#{space.guid}/managers",
            'auditors_url' => "/v2/spaces/#{space.guid}/auditors",
            'apps_url' => "/v2/spaces/#{space.guid}/apps",
            'routes_url' => "/v2/spaces/#{space.guid}/routes",
            'domains_url' => "/v2/spaces/#{space.guid}/domains",
            'service_instances_url' => "/v2/spaces/#{space.guid}/service_instances",
            'app_events_url' => "/v2/spaces/#{space.guid}/app_events",
            'events_url' => "/v2/spaces/#{space.guid}/events",
            'security_groups_url' => "/v2/spaces/#{space.guid}/security_groups",
            'staging_security_groups_url' => "/v2/spaces/#{space.guid}/staging_security_groups"
          }
        })
      end
    end
  end

  describe 'GET /v2/spaces/:guid/service_instances' do
    let(:originating_space) { VCAP::CloudController::Space.make }
    let(:shared_service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: originating_space) }
    let(:space) { VCAP::CloudController::Space.make }

    before do
      originating_space.organization.add_user(user)
      originating_space.add_developer(user)
      space.organization.add_user(user)
      space.add_developer(user)

      shared_service_instance.add_shared_space(space)
    end

    it 'shows the shared service instances associated with the space' do
      get "/v2/spaces/#{space.guid}/service_instances", {}, headers_for(user)

      expect(last_response.status).to eq(200)
      parsed_response = MultiJson.load(last_response.body)

      expect(parsed_response).to be_a_response_like({
        'total_results' => 1,
        'total_pages'   => 1,
        'prev_url'      => nil,
        'next_url'      => nil,
        'resources'     => [{
          'metadata' => {
            'guid' => shared_service_instance.guid,
            'url' => "/v2/service_instances/#{shared_service_instance.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601,
          },
          'entity' => {
            'name' => shared_service_instance.name,
            'credentials' => shared_service_instance.credentials,
            'service_plan_guid' => shared_service_instance.service_plan_guid,
            'space_guid' => originating_space.guid,
            'gateway_data' => nil,
            'dashboard_url' => nil,
            'type' => 'managed_service_instance',
            'last_operation' => nil,
            'tags' => [],
            'maintenance_info' => {},
            'service_guid' => shared_service_instance.service_plan.service_guid,
            'space_url' => "/v2/spaces/#{originating_space.guid}",
            'service_plan_url' => "/v2/service_plans/#{shared_service_instance.service_plan_guid}",
            'service_bindings_url' => "/v2/service_instances/#{shared_service_instance.guid}/service_bindings",
            'service_keys_url' => "/v2/service_instances/#{shared_service_instance.guid}/service_keys",
            'routes_url' => "/v2/service_instances/#{shared_service_instance.guid}/routes",
            'service_url' => "/v2/services/#{shared_service_instance.service_plan.service_guid}",
            'shared_from_url' => "/v2/service_instances/#{shared_service_instance.guid}/shared_from",
            'shared_to_url' => "/v2/service_instances/#{shared_service_instance.guid}/shared_to",
            'service_instance_parameters_url' => "/v2/service_instances/#{shared_service_instance.guid}/parameters",
          }
        }]
      })
    end
  end

  describe 'GET /v2/spaces/:guid/services' do
    let!(:space) { VCAP::CloudController::Space.make(organization: org) }
    let!(:service_1) { VCAP::CloudController::Service.make }
    let!(:service_plan_1) { VCAP::CloudController::ServicePlan.make(service: service_1) }
    let!(:service_2) { VCAP::CloudController::Service.make }
    let!(:service_plan_2) { VCAP::CloudController::ServicePlan.make(service: service_2) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    it 'lists services with the service broker name' do
      get "/v2/spaces/#{space.guid}/services", nil, headers_for(user)
      expect(last_response).to have_status_code(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response['resources'].first['entity']['service_broker_name']).to eq(service_1.service_broker.name)
      expect(parsed_response['resources'].second['entity']['service_broker_name']).to eq(service_2.service_broker.name)
    end
  end

  describe 'GET /v2/spaces/:guid/summary' do
    let!(:space) { VCAP::CloudController::Space.make(organization: org) }
    let!(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
    let!(:process) { VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED', app: app_model) }
    let(:maintenance_info) { { version: '1.0.0', desciption: 'this is description about the maintenance' } }
    let!(:service_plan) { VCAP::CloudController::ServicePlan.make(maintenance_info: maintenance_info) }
    let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan, maintenance_info: maintenance_info) }
    let(:build_client) { instance_double(Net::HTTP, request: nil) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      allow(build_client).to receive(:ipaddr=).and_return('1.2.3.4')
      allow(::Resolv).to receive(:getaddresses).and_return(['1.2.3.4'])
      allow_any_instance_of(::Diego::Client).to receive(:new_http_client).and_return(build_client)
    end

    it 'returns the space summary' do
      get "/v2/spaces/#{space.guid}/summary", nil, headers_for(user)
      expect(last_response).to have_status_code(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like({
        'guid' => space.guid,
        'name' => space.name,
        'apps' => [
          {
            'buildpack' => nil,
            'command' => nil,
            'console' => false,
            'debug' => nil,
            'detected_buildpack' => nil,
            'detected_buildpack_guid' => nil,
            'detected_start_command' => '$HOME/boot.sh',
            'diego' => true,
            'disk_quota' => 1024,
            'docker_image' => nil,
            'enable_ssh' => true,
            'environment_json' => nil,
            'guid' => process.guid,
            'health_check_http_endpoint' => nil,
            'health_check_timeout' => nil,
            'health_check_type' => 'port',
            'instances' => 1,
            'log_rate_limit' => 1_048_576,
            'memory' => 1024,
            'name' => process.name,
            'package_state' => 'STAGED',
            'package_updated_at' => process.package_updated_at.to_time.utc.iso8601,
            'ports' => nil,
            'production' => false,
            'routes' => [],
            'running_instances' => -1,
            'service_count' => 0,
            'service_names' => [],
            'space_guid' => space.guid,
            'stack_guid' => process.stack_guid,
            'staging_failed_description' => nil,
            'staging_failed_reason' => nil,
            'staging_task_id' => process.staging_task_id,
            'state' => 'STARTED',
            'urls' => [],
            'version' => process.version
          }
        ],
        'services' => [
          {
            'bound_app_count' => 0,
            'dashboard_url' => nil,
            'guid' => service_instance.guid,
            'last_operation' => nil,
            'name' => service_instance.name,
            'service_broker_name' => service_instance.service_broker.name,
            'maintenance_info' => service_instance.maintenance_info,
            'service_plan' => {
              'guid' => service_plan.guid,
              'name' => service_plan.name,
              'maintenance_info' => service_plan.maintenance_info,
              'service' => {
                'guid' => service_plan.service.guid,
                'label' => service_plan.service.label,
                'provider' => nil,
                'version' => nil
              }
            },
            'shared_from' => nil,
            'shared_to' => [],
            'type' => 'managed_service_instance'
          }
        ]
      })
    end
  end

  describe 'DELETE /v2/spaces/:guid/unmapped_routes' do
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:process) { VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED') }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    it 'deletes orphaned routes, does not delete mapped or bound routes' do
      unmapped_route = VCAP::CloudController::Route.make(space: space)

      mapped_route = VCAP::CloudController::Route.make(space: space)
      VCAP::CloudController::RouteMappingModel.make(app: process.app, route: mapped_route, app_port: 9090)

      bound_route = VCAP::CloudController::Route.make(space: space)
      service_instance = VCAP::CloudController::ManagedServiceInstance.make(:routing, space: space)
      VCAP::CloudController::RouteBinding.make(service_instance: service_instance, route: bound_route)

      delete "/v2/spaces/#{space.guid}/unmapped_routes", {}, headers_for(user)

      expect(last_response.status).to eq(204)
      expect(unmapped_route.exists?).to eq(false), "Expected route '#{unmapped_route.guid}' to not exist"
      expect(mapped_route.exists?).to eq(true), "Expected route '#{mapped_route.guid}' to exist"
      expect(bound_route.exists?).to eq(true), "Expected route '#{bound_route.guid}' to exist"
      expect(last_response.body).to be_empty
    end
  end
end
