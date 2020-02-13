require 'spec_helper'
require 'request_spec_shared_examples'
require 'models/services/service_plan'
require 'hashdiff'

UNAUTHENTICATED = %w[unauthenticated].freeze
COMPLETE_PERMISSIONS = (ALL_PERMISSIONS + UNAUTHENTICATED).freeze

RSpec.describe 'V3 service plans' do
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:maintenance_info_str) { '{"version": "1.0.0", "description":"best plan ever"}' }

  describe 'GET /v3/service_plans/:guid' do
    let(:api_call) { lambda { |user_headers| get "/v3/service_plans/#{guid}", nil, user_headers } }

    context 'when there is no service plan' do
      let(:guid) { 'no-such-plan' }

      let(:expected_codes_and_responses) do
        Hash.new(code: 404)
      end

      it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
    end

    context 'when there is a public service plan' do
      let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, maintenance_info: maintenance_info_str) }
      let(:guid) { service_plan.guid }

      let(:expected_codes_and_responses) do
        Hash.new(
          code: 200,
          response_object: create_plan_json(service_plan)
        )
      end

      it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS

      context 'when the hide_marketplace_from_unauthenticated_users feature flag is enabled' do
        before do
          VCAP::CloudController::FeatureFlag.create(name: 'hide_marketplace_from_unauthenticated_users', enabled: true)
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: create_plan_json(service_plan)
          )
          h['unauthenticated'] = { code: 401 }
          h
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end
    end

    context 'when there is a non-public service plan' do
      context 'global broker' do
        let!(:visibility) { VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan, organization: org) }
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, maintenance_info: maintenance_info_str) }
        let(:guid) { service_plan.guid }

        let(:expected_codes_and_responses) do
          Hash.new(code: 200, response_objects: create_plan_json(service_plan)).tap do |r|
            r['unauthenticated'] = { code: 404 }
            r['no_role'] = { code: 404 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end
      context 'space scoped broker' do
        let!(:broker) { VCAP::CloudController::ServiceBroker.make(space: space) }
        let!(:service_offering) { VCAP::CloudController::Service.make(service_broker: broker) }
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, service: service_offering, maintenance_info: maintenance_info_str) }
        let(:guid) { service_plan.guid }

        let(:expected_codes_and_responses) do
          Hash.new(code: 200, response_objects: create_plan_json(service_plan)).tap do |r|
            r['unauthenticated'] = { code: 404 }
            r['no_role'] = { code: 404 }
            r['org_billing_manager'] = { code: 404 }
            r['org_auditor'] = { code: 404 }
            r['org_manager'] = { code: 404 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end
    end

    context 'validity of links' do
      let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true) }
      let(:guid) { service_plan.guid }

      before do
        api_call.call(admin_headers)
      end

      it 'links to self' do
        get_plan_response = parsed_response

        get parsed_response['links']['self']['href'], {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response).to eq(get_plan_response)
      end

      it 'links to service offerings' do
        get parsed_response['links']['service_offering']['href'], {}, admin_headers
        expect(last_response).to have_status_code(200)
        link_response = parsed_response

        get "/v3/service_offerings/#{service_plan.service.guid}", {}, admin_headers
        expect(parsed_response).to eq(link_response)
      end

      it 'links to visibilities' do
        get parsed_response['links']['visibility']['href'], {}, admin_headers
        expect(last_response).to have_status_code(200)
        link_response = parsed_response

        get "/v3/service_plans/#{service_plan.guid}/visibility", {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response).to eq(link_response)
      end
    end
  end

  describe 'GET /v3/service_plans' do
    let(:api_call) { lambda { |user_headers| get '/v3/service_plans', nil, user_headers } }

    context 'when there are no service plans' do
      let(:expected_codes_and_responses) do
        Hash.new(
          code: 200,
          response_objects: []
        )
      end

      it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS
    end

    describe 'visibility of service plans' do
      let!(:public_service_plan) { VCAP::CloudController::ServicePlan.make(public: true, name: 'public') }
      let!(:private_service_plan) { VCAP::CloudController::ServicePlan.make(public: false, name: 'private') }
      let!(:space_scoped_service_plan) do
        service_broker = VCAP::CloudController::ServiceBroker.make(space: space)
        service_offering = VCAP::CloudController::Service.make(service_broker: service_broker)
        VCAP::CloudController::ServicePlan.make(service: service_offering)
      end
      let!(:org_restricted_service_plan) do
        service_plan = VCAP::CloudController::ServicePlan.make(public: false)
        VCAP::CloudController::ServicePlanVisibility.make(organization: org, service_plan: service_plan)
        service_plan
      end

      let(:all_plans_response) do
        {
          code: 200,
          response_objects: [
            create_plan_json(public_service_plan),
            create_plan_json(private_service_plan),
            create_plan_json(space_scoped_service_plan),
            create_plan_json(org_restricted_service_plan),
          ]
        }
      end

      let(:org_plans_response) do
        {
          code: 200,
          response_objects: [
            create_plan_json(public_service_plan),
            create_plan_json(org_restricted_service_plan),
          ]
        }
      end

      let(:space_plans_response) do
        {
          code: 200,
          response_objects: [
            create_plan_json(public_service_plan),
            create_plan_json(space_scoped_service_plan),
            create_plan_json(org_restricted_service_plan),
          ]
        }
      end

      let(:expected_codes_and_responses) do
        Hash.new(
          code: 200,
          response_objects: [
            create_plan_json(public_service_plan),
          ]
        ).tap do |h|
          h['admin'] = all_plans_response
          h['admin_read_only'] = all_plans_response
          h['global_auditor'] = all_plans_response
          h['org_manager'] = org_plans_response
          h['org_billing_manager'] = org_plans_response
          h['org_auditor'] = org_plans_response
          h['space_developer'] = space_plans_response
          h['space_manager'] = space_plans_response
          h['space_auditor'] = space_plans_response
        end
      end

      it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS

      context 'when the hide_marketplace_from_unauthenticated_users feature flag is enabled' do
        before do
          VCAP::CloudController::FeatureFlag.create(name: 'hide_marketplace_from_unauthenticated_users', enabled: true)
        end

        let(:expected_codes_and_responses) do
          Hash.new(code: 401)
        end

        it_behaves_like 'permissions for list endpoint', UNAUTHENTICATED
      end
    end

    describe 'filters' do
      describe 'organization_guids' do
        let(:org_1) { VCAP::CloudController::Organization.make }
        let(:org_2) { VCAP::CloudController::Organization.make }
        let(:plan_1) { VCAP::CloudController::ServicePlan.make(public: false) }
        let(:plan_2) { VCAP::CloudController::ServicePlan.make(public: false) }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: plan_1, organization: org_1)
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: plan_2, organization: org_2)
        end

        it 'selects on org guid' do
          get "/v3/service_plans?organization_guids=#{org_1.guid}", {}, admin_headers
          check_filtered_plans(plan_1)
        end
      end

      describe 'space_guids' do
        let(:org_1) { VCAP::CloudController::Organization.make }
        let(:org_2) { VCAP::CloudController::Organization.make }
        let(:plan_1) { VCAP::CloudController::ServicePlan.make(public: false) }
        let(:plan_2) { VCAP::CloudController::ServicePlan.make(public: false) }
        let(:space_1) { VCAP::CloudController::Space.make(organization: org_1) }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: plan_1, organization: org_1)
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: plan_2, organization: org_2)
        end

        it 'selects on org guid' do
          get "/v3/service_plans?space_guids=#{space_1.guid}", {}, admin_headers
          check_filtered_plans(plan_1)
        end
      end

      describe 'service_broker_names' do
        let(:org_system) { VCAP::CloudController::Organization.make(name: 'system') }
        let!(:org_dev) { VCAP::CloudController::Organization.make(name: 'dev') }

        let(:space_1) { VCAP::CloudController::Space.make(organization: org_system) }

        let(:global_broker) { VCAP::CloudController::ServiceBroker.make(name: 'global_broker') }
        let(:service_offering) { VCAP::CloudController::Service.make(service_broker: global_broker) }
        let!(:plan_1) { VCAP::CloudController::ServicePlan.make(public: true, service: service_offering) }
        let!(:plan_2) { VCAP::CloudController::ServicePlan.make(public: false, service: service_offering) }
        let(:plan_3) { VCAP::CloudController::ServicePlan.make(public: false, service: service_offering) }
        let(:plan_4) { VCAP::CloudController::ServicePlan.make(public: false, service: service_offering) }

        let(:space_broker) { VCAP::CloudController::ServiceBroker.make(name: 'space_broker', space: space_1) }
        let(:space_offering) { VCAP::CloudController::Service.make(service_broker: space_broker) }
        let!(:space_plan_1) { VCAP::CloudController::ServicePlan.make(public: false, service: space_offering) }
        let!(:space_plan_2) { VCAP::CloudController::ServicePlan.make(public: false, service: space_offering) }

        let(:global_broker2) { VCAP::CloudController::ServiceBroker.make(name: 'global_broker2') }
        let(:global_offering) { VCAP::CloudController::Service.make(service_broker: global_broker2) }
        let!(:filtered_out_plan) { VCAP::CloudController::ServicePlan.make(public: true, service: global_offering) }

        let(:user) { VCAP::CloudController::User.make }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: plan_3, organization: org_system)
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: plan_4, organization: org_dev)

          space_1.organization.add_user(user)
          space_1.add_developer(user)

          space_1.add_service_broker(space_broker)
        end

        context 'space developer' do
          it 'filters by broker name' do
            get "/v3/service_plans?service_broker_names=#{space_broker.name},#{global_broker.name}", {}, headers_for(user)
            check_filtered_plans(plan_1, space_plan_1, space_plan_2, plan_3)
          end
        end
        context 'admin' do
          it 'filters by broker name' do
            get "/v3/service_plans?service_broker_names=#{space_broker.name}", {}, admin_headers
            check_filtered_plans(space_plan_1, space_plan_2)
          end
        end
      end

      describe 'service_offering_names' do
        let(:org_system) { VCAP::CloudController::Organization.make(name: 'system') }
        let!(:org_dev) { VCAP::CloudController::Organization.make(name: 'dev') }

        let(:space_1) do
          space = VCAP::CloudController::Space.make(organization: org_system)
          space.organization.add_user(user)
          space.add_developer(user)
          space
        end

        let(:global_broker) { VCAP::CloudController::ServiceBroker.make(name: 'global_broker') }
        let(:service_offering) { VCAP::CloudController::Service.make(service_broker: global_broker) }
        let!(:plan_1) { VCAP::CloudController::ServicePlan.make(public: true, service: service_offering) }
        let!(:plan_2) { VCAP::CloudController::ServicePlan.make(public: false, service: service_offering) }
        let(:plan_3) { VCAP::CloudController::ServicePlan.make(public: false, service: service_offering) }
        let(:plan_4) { VCAP::CloudController::ServicePlan.make(public: false, service: service_offering) }

        let(:space_broker) { VCAP::CloudController::ServiceBroker.make(name: 'space_broker') }
        let(:space_offering) { VCAP::CloudController::Service.make(service_broker: space_broker) }
        let!(:space_plan_1) { VCAP::CloudController::ServicePlan.make(public: false, service: space_offering) }
        let!(:space_plan_2) { VCAP::CloudController::ServicePlan.make(public: false, service: space_offering) }

        let(:global_broker2) { VCAP::CloudController::ServiceBroker.make(name: 'global_broker2') }
        let(:global_offering) { VCAP::CloudController::Service.make(service_broker: global_broker2) }
        let!(:filtered_out_plan) { VCAP::CloudController::ServicePlan.make(public: true, service: global_offering) }

        let(:user) { VCAP::CloudController::User.make }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: plan_3, organization: org_system)
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: plan_4, organization: org_dev)

          space_1.add_service_broker(space_broker)
        end

        context 'space developer' do
          it 'filters by offering name' do
            get "/v3/service_plans?service_offering_names=#{service_offering.name},#{space_offering.name}", {}, headers_for(user)
            check_filtered_plans(plan_1, space_plan_1, space_plan_2, plan_3)
          end
        end

        context 'admin' do
          it 'filters by offering name' do
            get "/v3/service_plans?service_offering_names=#{space_offering.name}", {}, admin_headers
            check_filtered_plans(space_plan_1, space_plan_2)
          end
        end
      end

      describe 'labels' do
        let!(:service_plan_1) { VCAP::CloudController::ServicePlan.make(public: true, active: true) }
        let!(:service_plan_2) { VCAP::CloudController::ServicePlan.make(public: true, active: true) }
        let!(:service_plan_3) { VCAP::CloudController::ServicePlan.make(public: true, active: true) }

        before do
          VCAP::CloudController::ServicePlanLabelModel.make(resource_guid: service_plan_1.guid, key_name: 'flavor', value: 'orange')
          VCAP::CloudController::ServicePlanLabelModel.make(resource_guid: service_plan_2.guid, key_name: 'flavor', value: 'orange')
          VCAP::CloudController::ServicePlanLabelModel.make(resource_guid: service_plan_3.guid, key_name: 'flavor', value: 'apple')
        end

        it 'can filter on labels' do
          get '/v3/service_plans?label_selector=flavor=orange', {}, admin_headers

          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources']).to have_exactly(2).items
          expect(parsed_response['resources'][0]).to match_json_response(create_plan_json(service_plan_1, labels: { flavor: 'orange' }))
          expect(parsed_response['resources'][1]).to match_json_response(create_plan_json(service_plan_2, labels: { flavor: 'orange' }))
        end
      end

      describe 'other filters' do
        let!(:selected_plan) { VCAP::CloudController::ServicePlan.make(active: true) }
        let!(:alternate_plan) { VCAP::CloudController::ServicePlan.make(active: false) }

        it 'gets the available plans' do
          [
            'available=true',
            "names=#{selected_plan.name}",
            "service_broker_guids=#{selected_plan.service.service_broker.guid}",
            "service_offering_guids=#{selected_plan.service.guid}",
            "broker_catalog_ids=#{selected_plan.unique_id}",
          ].each do |filter|
            get "/v3/service_plans?#{filter}", {}, admin_headers
            check_filtered_plans(selected_plan)
          end
        end

        it 'gets the unavailable plans' do
          get '/v3/service_plans?available=false', {}, admin_headers
          check_filtered_plans(alternate_plan)
        end
      end
    end
  end

  describe 'DELETE /v3/service_plans/:guid' do
    let(:api_call) { lambda { |user_headers| delete "/v3/service_plans/#{guid}", nil, user_headers } }

    let(:db_check) {
      lambda do
        expect(VCAP::CloudController::ServicePlan.all).to be_empty
      end
    }

    context 'when the service plan does not exist' do
      let(:guid) { 'non-existing-guid' }

      let(:expected_codes_and_responses) do
        Hash.new(code: 404).tap do |h|
          h['admin_read_only'] = { code: 403 }
          h['global_auditor'] = { code: 403 }
          h['unauthenticated'] = { code: 401 }
        end
      end

      it_behaves_like 'permissions for delete endpoint', COMPLETE_PERMISSIONS
    end

    context 'when the service plan exists and has no service instances' do
      let(:guid) { service_plan.guid }

      context 'when the plan is only visible to global scope users' do
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false) }

        let(:expected_codes_and_responses) do
          Hash.new(code: 404).tap do |h|
            h['admin'] = { code: 204 }
            h['admin_read_only'] = { code: 403 }
            h['global_auditor'] = { code: 403 }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for delete endpoint', COMPLETE_PERMISSIONS
      end

      context 'when the plan is public' do
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make }

        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['admin'] = { code: 204 }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for delete endpoint', COMPLETE_PERMISSIONS
      end

      context 'when the plan is visible only on some orgs' do
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false) }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan, organization: org)
        end

        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['admin'] = { code: 204 }
            h['no_role'] = { code: 404 }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for delete endpoint', COMPLETE_PERMISSIONS
      end

      context 'when the plan is from a space-scoped service broker' do
        let(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: space) }
        let(:service_offering) { VCAP::CloudController::Service.make(service_broker: service_broker) }
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering, public: false) }

        let(:expected_codes_and_responses) do
          Hash.new(code: 404).tap do |h|
            h['admin'] = { code: 204 }
            h['admin_read_only'] = { code: 403 }
            h['global_auditor'] = { code: 403 }
            h['space_developer'] = { code: 204 }
            h['space_manager'] = { code: 403 }
            h['space_auditor'] = { code: 403 }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for delete endpoint', COMPLETE_PERMISSIONS
      end
    end

    context 'when the service plan exists and has service instances' do
      let!(:service_plan) { VCAP::CloudController::ManagedServiceInstance.make.service_plan }

      it 'fails with a 422 unprocessable entity' do
        delete "/v3/service_plans/#{service_plan.guid}", {}, admin_headers

        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors'][0]['detail']).to match(/Please delete the service_instances associations for your service_plans/)
      end
    end

    describe 'audit events' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make }

      it 'emits an audit event' do
        delete "/v3/service_plans/#{service_plan.guid}", nil, admin_headers

        expect([
          { type: 'audit.service_plan.delete', actor: service_plan.service_broker.name },
        ]).to be_reported_as_events
      end
    end
  end

  describe 'PATCH /v3/service_plans/:guid' do
    let(:labels) { { potato: 'sweet' } }
    let(:annotations) { { style: 'mashed', amount: 'all' } }
    let(:update_request_body) {
      {
        metadata: {
          labels: labels,
          annotations: annotations
        }
      }
    }

    let(:api_call) { lambda { |user_headers| patch "/v3/service_plans/#{guid}", update_request_body.to_json, user_headers } }
    let(:guid) { service_plan.guid }

    it 'can update labels and annotations' do
      service_plan = VCAP::CloudController::ServicePlan.make(public: true, active: true)

      patch "/v3/service_plans/#{service_plan.guid}", update_request_body.to_json, admin_headers

      expect(last_response).to have_status_code(200)
      expect(parsed_response.deep_symbolize_keys).to include(update_request_body)
    end

    context 'when some labels are invalid' do
      let(:labels) { { potato: 'sweet invalid potato' } }
      let!(:service_plan) { VCAP::CloudController::ServicePlan.make(active: true) }

      it 'returns a proper failure' do
        patch "/v3/service_plans/#{service_plan.guid}", update_request_body.to_json, admin_headers

        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors'][0]['detail']).to match(/Metadata [\w\s]+ error/)
      end
    end

    context 'when some annotations are invalid' do
      let(:annotations) { { '/style' => 'sweet invalid style' } }
      let!(:service_plan) { VCAP::CloudController::ServicePlan.make(active: true) }

      it 'returns a proper failure' do
        patch "/v3/service_plans/#{service_plan.guid}", update_request_body.to_json, admin_headers

        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors'][0]['detail']).to match(/Metadata [\w\s]+ error/)
      end
    end

    context 'when the service plan does not exist' do
      it 'returns a not found error' do
        patch '/v3/service_plans/some-invalid-guid', update_request_body.to_json, admin_headers

        expect(last_response).to have_status_code(404)
      end
    end

    context 'permissions' do
      context 'when the plan is only visible to global scope users' do
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false) }

        let(:expected_codes_and_responses) do
          Hash.new(code: 404).tap do |h|
            h['admin'] = { code: 200, response_object: create_plan_json(service_plan, labels: labels, annotations: annotations) }
            h['admin_read_only'] = { code: 403 }
            h['global_auditor'] = { code: 403 }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end

      context 'when the plan is public' do
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make }

        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['admin'] = { code: 200, response_object: create_plan_json(service_plan, labels: labels, annotations: annotations) }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end

      context 'when the plan is visible only on some orgs' do
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false) }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan, organization: org)
        end

        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['admin'] = { code: 200, response_object: create_plan_json(service_plan, labels: labels, annotations: annotations) }
            h['no_role'] = { code: 404 }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end

      context 'when the plan is from a space-scoped service broker' do
        let(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: space) }
        let(:service_offering) { VCAP::CloudController::Service.make(service_broker: service_broker) }
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering, public: false) }

        let(:expected_codes_and_responses) do
          Hash.new(code: 404).tap do |h|
            h['admin'] = { code: 200, response_object: create_plan_json(service_plan, labels: labels, annotations: annotations) }
            h['admin_read_only'] = { code: 403 }
            h['global_auditor'] = { code: 403 }
            h['space_developer'] = { code: 200, response_object: create_plan_json(service_plan, labels: labels, annotations: annotations) }
            h['space_manager'] = { code: 403 }
            h['space_auditor'] = { code: 403 }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end
    end
  end

  def create_plan_json(service_plan, labels: {}, annotations: {})
    plan = {
      guid: service_plan.guid,
      created_at: iso8601,
      updated_at: iso8601,
      visibility_type: service_plan.visibility_type,
      available: match(boolean),
      name: service_plan.name,
      free: match(boolean),
      description: service_plan.description,
      broker_catalog: {
        id: service_plan.unique_id,
        metadata: {},
        features: {
          bindable: match(boolean),
          plan_updateable: match(boolean)
        }
      },
      schemas: {
        service_instance: {
          create: {},
          update: {}
        },
        service_binding: {
          create: {}
        }
      },
      maintenance_info: service_plan.maintenance_info_as_hash,
      relationships: {
        service_offering: {
          data: {
            guid: service_plan.service.guid
          }
        }
      },
      links: {
        self: {
          href: "#{link_prefix}/v3/service_plans/#{service_plan.guid}"
        },
        service_offering: {
          href: "#{link_prefix}/v3/service_offerings/#{service_plan.service.guid}"
        },
        visibility: {
          href: "#{link_prefix}/v3/service_plans/#{service_plan.guid}/visibility"
        }
      },
      metadata: {
        labels: labels,
        annotations: annotations
      }
    }

    if service_plan.service.service_broker.space
      plan[:relationships][:space] = { data: { guid: service_plan.service.service_broker.space.guid } }
      plan[:links][:space] = { href: "#{link_prefix}/v3/spaces/#{service_plan.service.service_broker.space.guid}" }
    end

    plan
  end

  def check_filtered_plans(*plans)
    expect(last_response).to have_status_code(200)
    expect(parsed_response['resources'].length).to be(plans.length)
    expect({ resources: parsed_response['resources'] }).to match_json_response(
      { resources: plans.map { |p| create_plan_json(p) } }
    )
  end
end
