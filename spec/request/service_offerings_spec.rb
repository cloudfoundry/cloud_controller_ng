require 'spec_helper'
require 'request_spec_shared_examples'
require 'models/services/service_plan'

RSpec.describe 'V3 service offerings' do
  let(:user) { VCAP::CloudController::User.make }

  describe 'GET /v3/service_offerings/:guid' do
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:api_call) { lambda { |user_headers| get "/v3/service_offerings/#{guid}", nil, user_headers } }

    let(:successful_response) do
      {
        code: 200,
        response_object: {
          'guid' => guid,
          'name' => service_offering.label,
          'description' => service_offering.description,
          'available' => true,
          'bindable' => true,
          'broker_service_offering_metadata' => service_offering.extra,
          'broker_service_offering_id' => service_offering.unique_id,
          'tags' => [],
          'requires' => [],
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'plan_updateable' => false,
          'shareable' => true
        }
      }
    end

    context 'when the service offering does not exist' do
      let(:guid) { 'does-not-exist' }

      let(:expected_codes_and_responses) do
        Hash.new(code: 404)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when service plan is not available in any orgs' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
      let(:service_offering) { service_plan.service }
      let(:guid) { service_offering.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = successful_response
        h['admin_read_only'] = successful_response
        h['global_auditor'] = successful_response
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when service offering is publicly available' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: true) }
      let(:service_offering) { service_plan.service }
      let(:guid) { service_offering.guid }

      let(:expected_codes_and_responses) do
        Hash.new(successful_response)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when a service offering plan is available only in some orgs' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
      let(:service_offering) { service_plan.service }
      let!(:service_plan_visibility) do
        VCAP::CloudController::ServicePlanVisibility.make(
          service_plan: service_plan,
          organization: org
        )
      end
      let(:guid) { service_offering.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new(successful_response)
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when service offering comes from space scoped broker' do
      # TODO: Think about this
    end
  end
end
