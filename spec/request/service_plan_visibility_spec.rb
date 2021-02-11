require 'spec_helper'
require 'request_spec_shared_examples'
require 'models/services/service_plan'

RSpec.describe 'V3 service plan visibility' do
  let(:user) { VCAP::CloudController::User.make }
  let!(:org) { VCAP::CloudController::Organization.make }
  let!(:other_org) { VCAP::CloudController::Organization.make }
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

      let(:response_object) do
        {
          'type' => 'space',
          'space' => {
            'guid' => space.guid,
            'name' => space.name
          }
        }
      end

      let(:space_response) do
        {
          code: 200,
          response_object: response_object
        }
      end

      let(:expected_codes_and_responses) do
        responses_for_space_restricted_single_endpoint(
          response_object,
          permitted_roles: %w(
            admin
            admin_read_only
            global_auditor
            space_developer
            space_manager
            space_auditor
          )
        )
      end

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
    let(:method) { :patch }
    let(:api_url) { "/v3/service_plans/#{guid}/visibility" }
    let(:api_call) { lambda { |user_headers| send(method.to_sym, api_url, req_body.to_json, user_headers) } }
    let(:guid) { service_plan.guid }
    let(:req_body) { { type: 'public' } }

    context 'when the plan current visibility is "admin"' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false) }

      let(:expected_codes_and_responses) do
        Hash.new(code: 404).tap do |h|
          h['admin'] = successful_response
          h['admin_read_only'] = { code: 403 }
          h['global_auditor'] = { code: 403 }
          h['unauthenticated'] = { code: 401 }
        end
      end

      context 'and its being updated to "admin"' do
        let(:req_body) { { type: 'admin' } }
        let(:successful_response) { { code: 200, response_object: { type: 'admin' } } }

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'and its being updated to "public"' do
        let(:successful_response) { { code: 200, response_object: { type: 'public' } } }

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'and its being updated to "organization"' do
        let(:req_body) { { type: 'organization', organizations: [{ guid: org.guid }, { guid: other_org.guid }] } }
        let(:org_response) { [{ name: org.name, guid: org.guid }, { name: other_org.name, guid: other_org.guid }] }
        let(:successful_response) { { code: 200, response_object: { type: 'organization', organizations: org_response } } }

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the plan current visibility is "public"' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true) }
      let(:expected_codes_and_responses) do
        Hash.new(code: 403).tap do |h|
          h['admin'] = successful_response
          h['unauthenticated'] = { code: 401 }
        end
      end

      context 'and its being updated to "public"' do
        let(:successful_response) { { code: 200, response_object: { type: 'public' } } }

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'and its being updated to "admin"' do
        let(:req_body) { { type: 'admin' } }
        let(:successful_response) { { code: 200, response_object: { type: 'admin' } } }

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'and its being updated to "organization"' do
        let(:req_body) { { type: 'organization', organizations: [{ guid: org.guid }, { guid: other_org.guid }] } }
        let(:org_response) { [{ name: org.name, guid: org.guid }, { name: other_org.name, guid: other_org.guid }] }
        let(:successful_response) { { code: 200, response_object: { type: 'organization', organizations: org_response } } }

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the plan current visibility is "organization"' do
      let!(:service_plan) do
        plan = VCAP::CloudController::ServicePlan.make(public: false)
        VCAP::CloudController::ServicePlanVisibility.make(organization: org, service_plan: plan)
        VCAP::CloudController::ServicePlanVisibility.make(organization: other_org, service_plan: plan)
        plan
      end

      context 'and another PATCH with organizations is sent' do
        let(:third_org) { VCAP::CloudController::Organization.make }

        it 'fails if the list of orgs is empty' do
          body = { type: 'organization', organizations: [] }.to_json
          patch api_url, body, admin_headers

          expect(last_response).to have_status_code(400)
        end

        it 'replaces the list of orgs' do
          body = { type: 'organization', organizations: [{ guid: third_org.guid }] }.to_json
          patch api_url, body, admin_headers

          expected_response = { type: 'organization', organizations: [{ name: third_org.name, guid: third_org.guid }] }
          expect(parsed_response).to eq(expected_response.with_indifferent_access)

          get api_url, {}, admin_headers
          expect(parsed_response).to eq(expected_response.with_indifferent_access)
        end
      end

      context 'and its being updated to "public"' do
        let(:successful_response) { { code: 200, response_object: { type: 'public' } } }
        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['admin'] = successful_response
            h['unauthenticated'] = { code: 401 }
            h['no_role'] = { code: 404 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
          let(:after_request_check) do
            lambda do
              visibilities = VCAP::CloudController::ServicePlanVisibility.where(service_plan: service_plan).all
              expect(visibilities).to be_empty
            end
          end
        end

        it 'returns a 404 for users of other orgs' do
          new_org = VCAP::CloudController::Organization.make
          user = VCAP::CloudController::User.make
          user.add_organization(new_org)
          patch api_url, req_body.to_json, headers_for(user)

          expect(last_response).to have_status_code 404
        end
      end

      context 'and its being updated to "admin"' do
        let(:req_body) { { type: 'admin' } }
        let(:successful_response) { { code: 200, response_object: { type: 'admin' } } }
        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['admin'] = successful_response
            h['no_role'] = { code: 404 }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
          let(:after_request_check) do
            lambda do
              visibilities = VCAP::CloudController::ServicePlanVisibility.where(service_plan: service_plan).all
              expect(visibilities).to be_empty
            end
          end
        end

        it 'returns a 404 for users of other orgs' do
          new_org = VCAP::CloudController::Organization.make
          user = VCAP::CloudController::User.make
          user.add_organization(new_org)
          patch api_url, req_body.to_json, headers_for(user)

          expect(last_response).to have_status_code 404
        end
      end
    end

    context 'when the plan current visibility is "space"' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(
          service: VCAP::CloudController::Service.make(
            service_broker: VCAP::CloudController::ServiceBroker.make(
              space: VCAP::CloudController::Space.make
            )
          )
        )
      end

      it 'cannot be updated' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors'][0]['detail']).to match(/cannot update plans with visibility type 'space'/)
      end
    end

    context 'regardless of the current plan visibility' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true) }

      context 'when the plan does not exist' do
        let(:guid) { 'invalid-plan-guid' }
        let(:req_body) { { type: 'public' } }

        it 'returns a 404 not found' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(404)
        end
      end

      context 'when the update request body is invalid' do
        let(:req_body) { { type: 'space' } }

        it 'returns a 400 bad request' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors'][0]['detail']).to match(/must be one of 'public', 'admin', 'organization'/)
        end
      end

      context 'when type is "organization" but no organization is passed' do
        it 'returns an error' do
          patch api_url, { type: 'organization' }.to_json, admin_headers

          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors'].first['detail']).to include("Organizations can't be blank")
        end
      end

      context 'when type is "organization" but the org does not exist' do
        let(:service_plan) do
          plan = VCAP::CloudController::ServicePlan.make(public: false)
          VCAP::CloudController::ServicePlanVisibility.make(organization: org, service_plan: plan)
          VCAP::CloudController::ServicePlanVisibility.make(organization: other_org, service_plan: plan)
          plan
        end

        it 'returns an error and rolls back any changes' do
          third_org = VCAP::CloudController::Organization.make
          body = { type: 'organization', organizations: [{ guid: third_org.guid }, { guid: 'invalid-guid' }] }.to_json
          patch api_url, body, admin_headers

          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors'].first['detail']).to include('with guid: invalid-guid')
          expect(service_plan.reload.visibility_type).to eq('organization')
          expect(service_plan.service_plan_visibilities.map(&:organization_guid)).to contain_exactly(org.guid, other_org.guid)
        end
      end
    end
  end

  describe 'POST /v3/service_plans/:guid/visibility' do
    let(:third_org) { VCAP::CloudController::Organization.make }
    let(:yet_another_org) { VCAP::CloudController::Organization.make }
    let(:api_url) { "/v3/service_plans/#{guid}/visibility" }
    let(:api_call) { lambda { |user_headers| post api_url, req_body.to_json, user_headers } }
    let(:guid) { service_plan.guid }
    let(:service_plan) do
      plan = VCAP::CloudController::ServicePlan.make(public: false)
      VCAP::CloudController::ServicePlanVisibility.make(organization: org, service_plan: plan)
      VCAP::CloudController::ServicePlanVisibility.make(organization: other_org, service_plan: plan)
      plan
    end
    let(:body) { { type: 'organization', organizations: [{ guid: third_org.guid }, { guid: yet_another_org.guid }] } }

    context 'when the plan current visibility is "organization"' do
      it 'can add new organizations' do
        expected_orgs = [org, other_org, third_org, yet_another_org].map do |o|
          { 'guid' => o.guid, 'name' => o.name }
        end

        post api_url, body.to_json, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['type']).to eq 'organization'
        expect(parsed_response).not_to have_key('organizations')

        get api_url, {}, admin_headers
        expect(parsed_response['type']).to eq 'organization'
        expect(parsed_response['organizations']).to match_array(expected_orgs)
      end

      it 'creates an audit event' do
        post api_url, body.to_json, admin_headers
        event = VCAP::CloudController::Event.find(type: 'audit.service_plan_visibility.update')
        expect(event).to be
        expect(event.actee).to eq(service_plan.guid)
        expect(event.data).to include({
          'request' => body.with_indifferent_access
        })
      end

      it 'ignores organizations that already have visibility' do
        body = { type: 'organization', organizations: [{ guid: org.guid }, { guid: third_org.guid }] }.to_json
        expected_orgs = [
          { 'name' => org.name, 'guid' => org.guid },
          { 'name' => other_org.name, 'guid' => other_org.guid },
          { 'name' => third_org.name, 'guid' => third_org.guid }
        ]

        post api_url, body, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['type']).to eq 'organization'
        expect(parsed_response).not_to have_key('organizations')

        get api_url, {}, admin_headers
        expect(parsed_response['type']).to eq 'organization'
        expect(parsed_response['organizations']).to match_array(expected_orgs)
      end

      context 'when the request contains no organization' do
        it 'returns a 400 bad request' do
          post api_url, { type: 'organization', organizations: [] }.to_json, admin_headers

          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors'].first['detail']).to include("Organizations can't be blank")
        end
      end

      context 'when the current visibility type is not organization' do
        let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true) }
        let(:body) { { type: 'organization', organizations: [{ guid: org.guid }] } }

        it 'updates the visibility type AND add the orgs' do
          post api_url, body.to_json, admin_headers

          expect(parsed_response['type']).to eq 'organization'
          expect(parsed_response).not_to have_key('organizations')
        end

        it 'creates an audit event' do
          post api_url, body.to_json, admin_headers
          event = VCAP::CloudController::Event.find(type: 'audit.service_plan_visibility.update')
          expect(event).to be
          expect(event.actee).to eq(service_plan.guid)
          expect(event.data).to include({
            'request' => body.with_indifferent_access
          })
        end
      end

      context 'when an org in the list does not exist' do
        it 'returns an error and rolls back any changes' do
          third_org = VCAP::CloudController::Organization.make
          body = { type: 'organization', organizations: [{ guid: third_org.guid }, { guid: 'invalid-guid' }] }.to_json
          post api_url, body, admin_headers

          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors'].first['detail']).to include('with guid: invalid-guid')
          expect(service_plan.reload.visibility_type).to eq('organization')
          expect(service_plan.service_plan_visibilities.map(&:organization_guid)).to contain_exactly(org.guid, other_org.guid)
        end
      end
    end

    context 'when the plan does not exist' do
      let(:guid) { 'invalid-plan-guid' }

      it 'returns a 404 not found' do
        post api_url, { type: 'organization', organizations: [] }.to_json, admin_headers

        expect(last_response).to have_status_code(404)
      end
    end

    context 'when the plan current visibility is "space"' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(
          service: VCAP::CloudController::Service.make(
            service_broker: VCAP::CloudController::ServiceBroker.make(
              space: VCAP::CloudController::Space.make
            )
          )
        )
      end

      it 'cannot be updated' do
        body = { type: 'organization', organizations: [{ guid: org.guid }] }.to_json
        post api_url, body, admin_headers

        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors'][0]['detail']).to match(/cannot update plans with visibility type 'space'/)
      end
    end

    context 'when request type is not "organization"' do
      let(:body) { { type: 'public' } }

      it 'behaves like a PATCH' do
        post api_url, body.to_json, admin_headers
        expect(last_response).to have_status_code(200)

        get api_url, {}, admin_headers
        expect(parsed_response).to eq({ 'type' => 'public' })
        visibilities = VCAP::CloudController::ServicePlanVisibility.where(service_plan: service_plan).all
        expect(visibilities).to be_empty
      end

      it 'creates an audit event' do
        post api_url, body.to_json, admin_headers
        event = VCAP::CloudController::Event.find(type: 'audit.service_plan_visibility.update')
        expect(event).to be
        expect(event.actee).to eq(service_plan.guid)
        expect(event.data).to include({
          'request' => body.with_indifferent_access
        })
      end
    end

    context 'permissions' do
      let(:req_body) { { type: 'organization', organizations: [{ guid: third_org.guid }] } }
      let(:successful_response) { { code: 200, response_object: { type: 'organization' } } }
      let(:expected_codes_and_responses) do
        Hash.new(code: 403).tap do |h|
          h['admin'] = successful_response
          h['unauthenticated'] = { code: 401 }
          h['no_role'] = { code: 404 }
        end
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      it 'returns a 404 for users of other orgs' do
        new_org = VCAP::CloudController::Organization.make
        user = VCAP::CloudController::User.make
        user.add_organization(new_org)
        post api_url, req_body.to_json, headers_for(user)

        expect(last_response).to have_status_code 404
      end
    end
  end

  describe 'DELETE /v3/service_plans/:guid/visibility/:org_guid' do
    let(:api_url) { "/v3/service_plans/#{guid}/visibility/#{org_guid}" }
    let(:api_call) { lambda { |user_headers| delete api_url, {}, user_headers } }
    let(:guid) { service_plan.guid }
    let(:org_guid) { org.guid }

    let(:service_plan) do
      plan = VCAP::CloudController::ServicePlan.make(public: false)
      VCAP::CloudController::ServicePlanVisibility.make(organization: org, service_plan: plan)
      VCAP::CloudController::ServicePlanVisibility.make(organization: other_org, service_plan: plan)
      plan
    end

    context 'when the plan does not exist' do
      let(:guid) { 'invalid-plan-guid' }

      it 'returns 404' do
        delete api_url, {}, admin_headers
        expect(last_response).to have_status_code(404)
      end
    end

    context 'when the plan is not visible on the organization' do
      let(:third_org) { VCAP::CloudController::Organization.make }
      let(:org_guid) { third_org.guid }

      it 'returns a 404' do
        delete api_url, {}, admin_headers
        expect(last_response).to have_status_code(404)
      end
    end

    context 'when the organization does not exist' do
      let(:org_guid) { 'some-invalid-org-guid' }

      it 'returns a 404' do
        delete api_url, {}, admin_headers
        expect(last_response).to have_status_code(404)
      end
    end

    context 'when the plan is not org restricted' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true) }

      it 'returns a 422' do
        delete api_url, {}, admin_headers
        expect(last_response).to have_status_code(422)
      end
    end

    context 'permissions' do
      let(:db_check) do
        lambda do
          expect(VCAP::CloudController::ServicePlanVisibility.all.map(&:organization_id)).to eq([other_org.id])
        end
      end

      let(:successful_response) { { code: 204 } }
      let(:expected_codes_and_responses) do
        Hash.new(code: 403).tap do |h|
          h['admin'] = successful_response
          h['unauthenticated'] = { code: 401 }
          h['no_role'] = { code: 404 }
        end
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
    end

    it 'creates an audit event' do
      delete api_url, {}, admin_headers
      expect(last_response).to have_status_code(204)
      event = VCAP::CloudController::Event.find(type: 'audit.service_plan_visibility.delete')
      expect(event).to be
      expect(event.actee).to eq(service_plan.guid)
      expect(event.organization_guid).to eq(org.guid)
    end
  end
end
