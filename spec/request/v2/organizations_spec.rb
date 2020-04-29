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

      parsed_response = MultiJson.load(last_response.body)
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
                'label'                 => service_1.label,
                'provider'              => service_1.provider,
                'url'                   => service_1.url,
                'description'           => service_1.description,
                'long_description'      => service_1.long_description,
                'version'               => service_1.version,
                'info_url'              => service_1.info_url,
                'active'                => service_1.active,
                'bindable'              => service_1.bindable,
                'unique_id'             => service_1.unique_id,
                'extra'                 => service_1.extra,
                'tags'                  => service_1.tags,
                'requires'              => service_1.requires,
                'documentation_url'     => service_1.documentation_url,
                'service_broker_guid'   => service_1.service_broker.guid,
                'service_broker_name'   => service_1.service_broker.name,
                'plan_updateable'       => service_1.plan_updateable,
                'bindings_retrievable'  => service_1.bindings_retrievable,
                'instances_retrievable' => service_1.instances_retrievable,
                'allow_context_updates' => service_1.allow_context_updates,
                'service_plans_url'     => "/v2/services/#{service_1.guid}/service_plans"
              }
            },
            {
              'metadata' => {
                'guid' => service_2.guid,
                'url' => "/v2/services/#{service_2.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity'                  => {
                'label'                 => service_2.label,
                'provider'              => service_2.provider,
                'url'                   => service_2.url,
                'description'           => service_2.description,
                'long_description'      => service_2.long_description,
                'version'               => service_2.version,
                'info_url'              => service_2.info_url,
                'active'                => service_2.active,
                'bindable'              => service_2.bindable,
                'unique_id'             => service_2.unique_id,
                'extra'                 => service_2.extra,
                'tags'                  => service_2.tags,
                'requires'              => service_2.requires,
                'documentation_url'     => service_2.documentation_url,
                'service_broker_guid'   => service_2.service_broker.guid,
                'service_broker_name'   => service_2.service_broker.name,
                'plan_updateable'       => service_2.plan_updateable,
                'bindings_retrievable'  => service_2.bindings_retrievable,
                'instances_retrievable' => service_2.instances_retrievable,
                'allow_context_updates' => service_2.allow_context_updates,
                'service_plans_url'     => "/v2/services/#{service_2.guid}/service_plans"
              }
            }
          ]
        }
      )
    end
  end
end
