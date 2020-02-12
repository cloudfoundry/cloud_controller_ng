require 'spec_helper'
require 'request_spec_shared_examples'
require 'models/services/service_plan'

RSpec.describe 'V3 service plan visibility' do
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }

  describe 'GET /v3/service_plans/:guid/visibility' do
    let(:api_call) { lambda { |user_headers| get "/v3/service_plans/#{guid}/visibility", {}, user_headers } }
    let(:guid) { service_plan.guid }

    context 'when the plan does not exist' do
      let(:guid) { 'invalid-guid' }

      it 'returns a 404' do
        api_call.call(admin_headers)

        expect(last_response).to have_status_code(404)
      end
    end

    context 'for public plans' do
      let!(:service_plan) { VCAP::CloudController::ServicePlan.make }
      let(:expected_codes_and_responses) {
        Hash.new(
          code: 200,
          response_object: { 'type' => 'public' }
        )
      }

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'for admin-only plans' do
      let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false) }
      let(:admin_only_response) {
        {
          code: 200,
          response_object: { 'type' => 'admin' }
        }
      }
      let(:expected_codes_and_responses) {
        Hash.new(code: 404).tap do |h|
          h['admin'] = admin_only_response
          h['admin_read_only'] = admin_only_response
          h['global_auditor'] = admin_only_response
        end
      }

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'for space-scoped plans' do
      let!(:service_plan) do
        broker = VCAP::CloudController::ServiceBroker.make(space: space)
        offering = VCAP::CloudController::Service.make(service_broker: broker)
        VCAP::CloudController::ServicePlan.make(public: false, service: offering)
      end

      let(:space_response) {
        {
          code: 200,
          response_object: {
            'type' => 'space',
            'space' => {
              'guid' => space.guid,
              'name' => space.name
            }
          }
        }
      }
      let(:expected_codes_and_responses) {
        Hash.new(code: 404).tap do |h|
          h['admin'] = space_response
          h['admin_read_only'] = space_response
          h['global_auditor'] = space_response
          h['space_developer'] = space_response
          h['space_manager'] = space_response
          h['space_auditor'] = space_response
        end
      }

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'for org-restricted plans' do
      let(:other_org) { VCAP::CloudController::Organization.make }

      let!(:service_plan) do
        plan = VCAP::CloudController::ServicePlan.make(public: false)
        VCAP::CloudController::ServicePlanVisibility.make(organization: org, service_plan: plan)
        VCAP::CloudController::ServicePlanVisibility.make(organization: other_org, service_plan: plan)
        plan
      end

      let(:admin_org_response) {
        {
          code: 200,
          response_object: {
            'type' => 'organization',
            'organizations' => [{
              'guid' => org.guid,
              'name' => org.name
            }, {
              'guid' => other_org.guid,
              'name' => other_org.name
            }]
          }
        }
      }

      let(:org_member_response) {
        {
          code: 200,
          response_object: {
            'type' => 'organization',
            'organizations' => [{
              'guid' => org.guid,
              'name' => org.name
            }]
          }
        }
      }

      let(:expected_codes_and_responses) {
        Hash.new(org_member_response).tap do |h|
          h['admin'] = admin_org_response
          h['admin_read_only'] = admin_org_response
          h['global_auditor'] = admin_org_response
          h['no_role'] = { code: 404 }
        end
      }

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end

  describe 'PATCH /v3/service_plans/:guid/visibility' do
    let(:api_call) { lambda { |user_headers| patch "/v3/service_plans/#{guid}/visibility", req_body.to_json, user_headers } }
    let(:guid) { service_plan.guid }

    context 'when the plan current visibility is "admin"' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false) }

      context 'and its being updated to public' do
        let(:req_body) { { type: 'public' } }
        let(:successful_response) { { code: 200, response_object: { type: 'public' } } }

        let(:expected_codes_and_responses) do
          Hash.new(code: 404).tap do |h|
            h['admin'] = successful_response
            h['admin_read_only'] = { code: 403 }
            h['global_auditor'] = { code: 403 }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the plan current visibility is "public"' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true) }

      context 'and its being updated to "admin"' do
        let(:req_body) { { type: 'admin' } }
        let(:successful_response) { { code: 200, response_object: { type: 'admin' } } }

        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['admin'] = successful_response
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the plan does not exist' do
      let(:guid) { 'invalid-plan-guid' }
      let(:req_body) { { type: 'public' } }

      it 'returns a 404 not found' do
        api_call.call(admin_headers)

        expect(last_response).to have_status_code(404)
      end
    end

    context 'when the update request body is invalid' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false) }
      let(:req_body) { { type: 'space' } }

      it 'returns a 400 bad request' do
        api_call.call(admin_headers)

        expect(last_response).to have_status_code(400)
        p parsed_response
        expect(parsed_response['errors'][0]['detail']).to match(/must be one of 'public', 'admin', 'organization'/)
      end
    end
  end
end
