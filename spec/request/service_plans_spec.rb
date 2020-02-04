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

    context 'visibility of service plans' do
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
  end

  def create_plan_json(service_plan)
    plan = {
      guid: service_plan.guid,
      created_at: iso8601,
      updated_at: iso8601,
      public: match(boolean),
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
        }
      }
    }

    if service_plan.service.service_broker.space
      plan[:relationships][:space] = { data: { guid: service_plan.service.service_broker.space.guid } }
      plan[:links][:space] = { href: "#{link_prefix}/v3/spaces/#{service_plan.service.service_broker.space.guid}" }
    end

    plan
  end
end
