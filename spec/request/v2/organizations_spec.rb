require 'spec_helper'

RSpec.describe 'Organizations' do
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }

  before do
    TestConfig.override(kubernetes: {})
  end

  describe 'GET /v2/organizations/:guid/services' do
    let!(:space) { VCAP::CloudController::Space.make(organization: org) }
    let!(:service_1) { VCAP::CloudController::Service.make }
    let!(:service_plan_1) { VCAP::CloudController::ServicePlan.make(service: service_1) }
    let!(:service_2) { VCAP::CloudController::Service.make }
    let!(:service_plan_2) { VCAP::CloudController::ServicePlan.make(service: service_2) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    it 'lists services' do
      get "/v2/organizations/#{org.guid}/services", nil, headers_for(user)
      expect(last_response).to have_status_code(200)

      parsed_response = Oj.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'total_results' => 2,
          'total_pages' => 1,
          'prev_url' => nil,
          'next_url' => nil,
          'resources' => [
            {
              'metadata' => {
                'guid' => service_1.guid,
                'url' => "/v2/services/#{service_1.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity' => {
                'label' => service_1.label,
                'provider' => service_1.provider,
                'url' => service_1.url,
                'description' => service_1.description,
                'long_description' => service_1.long_description,
                'version' => service_1.version,
                'info_url' => service_1.info_url,
                'active' => service_1.active,
                'bindable' => service_1.bindable,
                'unique_id' => service_1.unique_id,
                'extra' => service_1.extra,
                'tags' => service_1.tags,
                'requires' => service_1.requires,
                'documentation_url' => service_1.documentation_url,
                'service_broker_guid' => service_1.service_broker.guid,
                'service_broker_name' => service_1.service_broker.name,
                'plan_updateable' => service_1.plan_updateable,
                'bindings_retrievable' => service_1.bindings_retrievable,
                'instances_retrievable' => service_1.instances_retrievable,
                'allow_context_updates' => service_1.allow_context_updates,
                'service_plans_url' => "/v2/services/#{service_1.guid}/service_plans"
              }
            },
            {
              'metadata' => {
                'guid' => service_2.guid,
                'url' => "/v2/services/#{service_2.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity' => {
                'label' => service_2.label,
                'provider' => service_2.provider,
                'url' => service_2.url,
                'description' => service_2.description,
                'long_description' => service_2.long_description,
                'version' => service_2.version,
                'info_url' => service_2.info_url,
                'active' => service_2.active,
                'bindable' => service_2.bindable,
                'unique_id' => service_2.unique_id,
                'extra' => service_2.extra,
                'tags' => service_2.tags,
                'requires' => service_2.requires,
                'documentation_url' => service_2.documentation_url,
                'service_broker_guid' => service_2.service_broker.guid,
                'service_broker_name' => service_2.service_broker.name,
                'plan_updateable' => service_2.plan_updateable,
                'bindings_retrievable' => service_2.bindings_retrievable,
                'instances_retrievable' => service_2.instances_retrievable,
                'allow_context_updates' => service_2.allow_context_updates,
                'service_plans_url' => "/v2/services/#{service_2.guid}/service_plans"
              }
            }
          ]
        }
      )
    end
  end

  describe 'PUT /v2/organizations/:guid' do
    context 'when the quota has a finite log rate limit and there are apps with unlimited log rates' do
      let(:admin_header) { headers_for(user, scopes: %w[cloud_controller.admin]) }
      let(:org_quota) { VCAP::CloudController::QuotaDefinition.make(log_rate_limit: 100) }

      let(:params) do
        {
          quota_definition_guid: org_quota.guid
        }
      end

      let!(:space) { VCAP::CloudController::Space.make(organization: org) }
      let!(:app_model) { VCAP::CloudController::AppModel.make(name: 'name1', space: space) }
      let!(:process_model) { VCAP::CloudController::ProcessModel.make(app: app_model, log_rate_limit: -1) }

      it 'returns 422' do
        put "/v2/organizations/#{org.guid}", params.to_json, admin_header
        expect(last_response).to have_status_code(422)
        expect(decoded_response['error_code']).to eq('CF-UnprocessableEntity')
        expect(decoded_response['description']).to eq('Current usage exceeds new quota values. This org currently contains apps running with an unlimited log rate limit.')
      end
    end

    context 'when a OrgManager mutates the status field' do
      let(:org_manager) { VCAP::CloudController::User.make }
      let(:org_manager_header) { headers_for(org_manager) }
      let(:admin_header) { headers_for(user, scopes: %w[cloud_controller.admin]) }

      before do
        org.add_user(org_manager)
        org.add_manager(org_manager)
      end

      it 'returns 403 NotAuthorized when attempting to suspend an active org' do
        put "/v2/organizations/#{org.guid}", { status: 'suspended' }.to_json, org_manager_header

        expect(last_response).to have_status_code(403)
        expect(decoded_response['error_code']).to eq('CF-NotAuthorized')
        expect(org.reload).not_to be_suspended
      end

      it 'returns 403 NotAuthorized when attempting to un-suspend a suspended org' do
        org.update(status: VCAP::CloudController::Organization::SUSPENDED)

        put "/v2/organizations/#{org.guid}", { status: 'active' }.to_json, org_manager_header

        expect(last_response).to have_status_code(403)
        expect(decoded_response['error_code']).to eq('CF-NotAuthorized')
        expect(org.reload).to be_suspended
      end

      it 'still allows an admin to mutate status' do
        put "/v2/organizations/#{org.guid}", { status: 'suspended' }.to_json, admin_header

        expect(last_response).to have_status_code(201)
        expect(org.reload).to be_suspended
      end

      it 'allows a no-op status update (status matches current state) by an OrgManager' do
        put "/v2/organizations/#{org.guid}", { status: 'active' }.to_json, org_manager_header

        expect(last_response).to have_status_code(201)
        expect(org.reload).not_to be_suspended
      end
    end
  end

  describe 'POST /v2/organizations' do
    context 'when a non-admin sets status to suspended at create' do
      let(:user_header) { headers_for(user) }
      let(:admin_header) { headers_for(user, scopes: %w[cloud_controller.admin]) }

      before do
        VCAP::CloudController::FeatureFlag.create(name: 'user_org_creation', enabled: true)
      end

      it 'returns 403 NotAuthorized when a non-admin attempts to create a suspended org' do
        post '/v2/organizations', { name: 'suspended-at-birth', status: 'suspended' }.to_json, user_header

        expect(last_response).to have_status_code(403)
        expect(decoded_response['error_code']).to eq('CF-NotAuthorized')
        expect(VCAP::CloudController::Organization.find(name: 'suspended-at-birth')).to be_nil
      end

      it 'allows a non-admin to create an org with status: active (the default) as a no-op' do
        post '/v2/organizations', { name: 'noop-active-org', status: 'active' }.to_json, user_header

        expect(last_response).to have_status_code(201)
        created = VCAP::CloudController::Organization.find(name: 'noop-active-org')
        expect(created).not_to be_nil
        expect(created).not_to be_suspended
      end

      it 'still allows an admin to create a suspended org' do
        post '/v2/organizations', { name: 'admin-suspended-org', status: 'suspended' }.to_json, admin_header

        expect(last_response).to have_status_code(201)
        expect(VCAP::CloudController::Organization.find(name: 'admin-suspended-org')).to be_suspended
      end
    end
  end
end
