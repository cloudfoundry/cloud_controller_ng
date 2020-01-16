require 'spec_helper'
require 'request_spec_shared_examples'
require 'models/services/service_plan'
require 'hashdiff'

ADDITIONAL_ROLES = %w[unauthenticated].freeze
COMPLETE_PERMISSIONS = (ALL_PERMISSIONS + ADDITIONAL_ROLES).freeze

RSpec.describe 'V3 service offerings' do
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }

  describe 'GET /v3/service_offerings/:guid' do
    let(:api_call) { lambda { |user_headers| get "/v3/service_offerings/#{service_offering.guid}", nil, user_headers } }

    let(:successful_response) do
      {
        code: 200,
        response_object: create_offering_json(service_offering)
      }
    end

    context 'when the service offering does not exist' do
      let(:api_call) { lambda { |user_headers| get '/v3/service_offerings/does-not-exist-guid', nil, user_headers } }

      let(:expected_codes_and_responses) do
        Hash.new(code: 404)
      end

      it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
    end

    context 'when service plan is not available in any orgs' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
      let(:service_offering) { service_plan.service }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = successful_response
        h['admin_read_only'] = successful_response
        h['global_auditor'] = successful_response
        h
      end

      it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
    end

    context 'when service offering is publicly available' do
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: true) }
      let(:service_offering) { service_plan.service }

      let(:expected_codes_and_responses) do
        Hash.new(successful_response)
      end

      it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS

      context 'when the hide_marketplace_from_unauthenticated_users feature flag is enabled' do
        before do
          VCAP::CloudController::FeatureFlag.create(name: 'hide_marketplace_from_unauthenticated_users', enabled: true)
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(successful_response)
          h['unauthenticated'] = { code: 401 }
          h
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end
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

      let(:expected_codes_and_responses) do
        h = Hash.new(successful_response)
        h['no_role'] = { code: 404 }
        h['unauthenticated'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
    end

    context 'when service offering comes from space scoped broker' do
      let!(:broker_org) { VCAP::CloudController::Organization.make }
      let!(:broker_space) { VCAP::CloudController::Space.make(organization: broker_org) }
      let!(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: broker_space) }
      let!(:service_offering) { VCAP::CloudController::Service.make(service_broker: service_broker) }
      let!(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
      let!(:guid) { service_offering.guid }

      context 'the user is in the same space as the service broker' do
        let(:user) { VCAP::CloudController::User.make }
        let(:org) { broker_org }
        let(:space) { broker_space }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 404)
          h['admin'] = successful_response
          h['admin_read_only'] = successful_response
          h['global_auditor'] = successful_response
          h['space_developer'] = successful_response
          h['space_manager'] = successful_response
          h['space_auditor'] = successful_response
          h
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end

      context 'the user is in a different space to the service broker' do
        let(:user) { VCAP::CloudController::User.make }
        let(:org) { VCAP::CloudController::Organization.make }
        let(:space) { VCAP::CloudController::Space.make(organization: org) }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 404)
          h['admin'] = successful_response
          h['admin_read_only'] = successful_response
          h['global_auditor'] = successful_response
          h
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end

      context 'the user is a SpaceDeveloper in the space of the broker, but is targeting a different space' do
        let(:user) { VCAP::CloudController::User.make }
        let(:org) { VCAP::CloudController::Organization.make }
        let(:space) { VCAP::CloudController::Space.make(organization: org) }

        before do
          broker_org.add_user(user)
          broker_space.add_developer(user)
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(successful_response)
          h['unauthenticated'] = { code: 404 }
          h
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end
    end
  end

  describe 'GET /v3/service_offerings' do
    let(:api_call) { lambda { |user_headers| get '/v3/service_offerings', nil, user_headers } }

    context 'when there are no service offerings' do
      let(:expected_codes_and_responses) do
        Hash.new(
          code: 200,
          response_objects: []
        )
      end

      it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS
    end

    context 'visibility of service offerings' do
      context 'when there are public service offerings' do
        let!(:service_offering_1) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }
        let!(:service_offering_2) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }

        let(:expected_codes_and_responses) do
          Hash.new(
            code: 200,
            response_objects: [
              create_offering_json(service_offering_1),
              create_offering_json(service_offering_2)
            ]
          )
        end

        it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS

        context 'when the hide_marketplace_from_unauthenticated_users feature flag is enabled' do
          before do
            VCAP::CloudController::FeatureFlag.create(name: 'hide_marketplace_from_unauthenticated_users', enabled: true)
          end

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                create_offering_json(service_offering_1),
                create_offering_json(service_offering_2)
              ]
            )
            h['unauthenticated'] = { code: 401 }
            h
          end

          it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS
        end
      end

      context 'when a service offerings is available in some orgs' do
        let!(:space) { VCAP::CloudController::Space.make }
        let!(:org_1) { space.organization }
        let!(:service_plan_1) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
        let!(:service_offering_1) { service_plan_1.service }
        let!(:visibility_1) { VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan_1, organization: org_1) }

        let!(:org_2) { VCAP::CloudController::Organization.make }
        let!(:service_plan_2) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
        let!(:service_offering_2) { service_plan_2.service }
        let!(:visibility_2) { VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan_2, organization: org_2) }

        let!(:org_3) { VCAP::CloudController::Organization.make }

        let(:user) { VCAP::CloudController::User.make }
        let(:org) { org_1 }

        let(:both_offerings_response) do
          {
            code: 200,
            response_objects: [
              create_offering_json(service_offering_1),
              create_offering_json(service_offering_2)
            ]
          }
        end

        let(:one_offering_response) do
          {
            code: 200,
            response_objects: [
              create_offering_json(service_offering_1)
            ]
          }
        end

        let(:no_offerings_response) do
          {
            code: 200,
            response_objects: []
          }
        end

        let(:expected_codes_and_responses) do
          h = {}
          h['admin'] = both_offerings_response
          h['admin_read_only'] = both_offerings_response
          h['global_auditor'] = both_offerings_response
          h['org_manager'] = one_offering_response
          h['org_auditor'] = one_offering_response
          h['org_billing_manager'] = one_offering_response
          h['space_developer'] = one_offering_response
          h['space_manager'] = one_offering_response
          h['space_auditor'] = one_offering_response
          h['no_role'] = no_offerings_response
          h['unauthenticated'] = no_offerings_response
          h
        end

        it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS
      end

      context 'when there are space-scoped brokers' do
        let!(:broker_org) { VCAP::CloudController::Organization.make }
        let!(:broker_space) { VCAP::CloudController::Space.make(organization: broker_org) }
        let!(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: broker_space) }
        let!(:service_offering) { VCAP::CloudController::Service.make(service_broker: service_broker) }
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
        let!(:guid) { service_offering.guid }

        context 'the user is in the same space as the service broker' do
          let(:org) { broker_org }
          let(:space) { broker_space }

          let(:successful_response) do
            {
              code: 200,
              response_objects: [
                create_offering_json(service_offering)
              ]
            }
          end

          let(:expected_codes_and_responses) do
            h = Hash.new({
              code: 200,
              response_objects: []
            })
            h['admin'] = successful_response
            h['admin_read_only'] = successful_response
            h['global_auditor'] = successful_response
            h['space_developer'] = successful_response
            h['space_manager'] = successful_response
            h['space_auditor'] = successful_response
            h
          end

          it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS
        end

        context 'the user is in a different space to the service broker' do
          let(:successful_response) do
            {
              code: 200,
              response_objects: [
                create_offering_json(service_offering)
              ]
            }
          end

          let(:expected_codes_and_responses) do
            h = Hash.new({
              code: 200,
              response_objects: []
            })
            h['admin'] = successful_response
            h['admin_read_only'] = successful_response
            h['global_auditor'] = successful_response
            h
          end

          it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS
        end

        context 'the user is a SpaceDeveloper in the space of the broker, but is targeting a different space' do
          let(:user) { VCAP::CloudController::User.make }

          before do
            broker_org.add_user(user)
            broker_space.add_developer(user)
          end

          let(:expected_codes_and_responses) do
            Hash.new(code: 200,
              response_objects: [
                create_offering_json(service_offering)
              ]
            )
          end

          it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS # Does not make sense to test 'unauthenticated'
        end
      end

      context 'when there is a mixture of service offering types' do
        # public - can see
        let!(:service_offering_1) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }

        # available in no orgs - cannot see
        let!(:service_offering_2) { VCAP::CloudController::ServicePlan.make(public: false, active: true).service }

        # visible in org 1 - can see
        let!(:org_1) { VCAP::CloudController::Organization.make }
        let!(:org_2) { VCAP::CloudController::Organization.make }
        let!(:service_plan_1) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
        let!(:service_offering_3) { service_plan_1.service }
        let!(:visibility_1) { VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan_1, organization: org_1) }

        # visible in org 3 - cannot see
        let!(:org_3) { VCAP::CloudController::Organization.make }
        let!(:service_plan_2) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
        let!(:service_offering_4) { service_plan_1.service }
        let!(:visibility_2) { VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan_2, organization: org_3) }

        let!(:space_1) { VCAP::CloudController::Space.make }
        let!(:space_2) { VCAP::CloudController::Space.make }
        let!(:space_3) { VCAP::CloudController::Space.make }
        let!(:service_offering_5) { VCAP::CloudController::ServicePlan.make(public: false, active: true).service }
        let!(:service_offering_6) { VCAP::CloudController::ServicePlan.make(public: false, active: true).service }
        before do
          service_offering_5.service_broker.space = space_1 # visible if member of space 1 - can see
          service_offering_5.service_broker.save
          service_offering_6.service_broker.space = space_2 # visible if member of space 2 - cannot see
          service_offering_6.service_broker.save
        end

        let(:user) { VCAP::CloudController::User.make }

        it 'can only see the services it is meant to see' do
          org_1.add_user(user)
          space_1.organization.add_user(user)
          space_1.add_developer(user)

          get '/v3/service_offerings', nil, headers_for(user)

          expect(last_response).to have_status_code(200)
          response_guids = parsed_response['resources'].map { |r| r['guid'] }
          expect(response_guids).to match_array([service_offering_1.guid, service_offering_3.guid, service_offering_5.guid])
        end
      end
    end

    context 'when requesting one service offering per page' do
      let!(:service_offering_1) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }
      let!(:service_offering_2) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }

      it 'returns 200 OK and a body containing one broker with pagination information for the next' do
        expect_filtered_service_offerings('per_page=1', [service_offering_1])

        expect(parsed_response['pagination']['total_results']).to eq(2)
        expect(parsed_response['pagination']['total_pages']).to eq(2)
      end
    end

    context 'filters and sorting' do
      context 'when filtering on the `available` property' do
        let(:api_call) { lambda { |user_headers| get "/v3/service_offerings?available=#{available}", nil, user_headers } }

        let!(:service_offering_available) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }
        let!(:service_offering_unavailable) do
          offering = VCAP::CloudController::Service.make(active: false)
          VCAP::CloudController::ServicePlan.make(public: true, active: true, service: offering)
          offering
        end

        context 'filtering for available offerings' do
          let(:available) { true }
          let(:expected_codes_and_responses) do
            Hash.new(
              code: 200,
              response_objects: [
                create_offering_json(service_offering_available),
              ]
            )
          end

          it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS
        end

        context 'filtering for unavailable offerings' do
          let(:available) { false }
          let(:expected_codes_and_responses) do
            Hash.new(
              code: 200,
              response_objects: [
                create_offering_json(service_offering_unavailable),
              ]
            )
          end

          it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS
        end
      end

      context 'when filtering on the service broker GUID' do
        let(:api_call) { lambda { |user_headers| get "/v3/service_offerings?service_broker_guids=#{service_broker_guids.join(',')}", nil, user_headers } }
        let(:service_broker_guids) { [service_broker.guid, service_offering_3.service_broker.guid] }

        let(:expected_codes_and_responses) do
          Hash.new(
            code: 200,
            response_objects: [
              create_offering_json(service_offering_1),
              create_offering_json(service_offering_2),
              create_offering_json(service_offering_3),
            ]
          )
        end

        let!(:service_broker) { VCAP::CloudController::ServiceBroker.make }
        let!(:service_offering_1) do
          offering = VCAP::CloudController::Service.make(service_broker: service_broker)
          VCAP::CloudController::ServicePlan.make(public: true, service: offering)
          offering
        end
        let!(:service_offering_2) do
          offering = VCAP::CloudController::Service.make(service_broker: service_broker)
          VCAP::CloudController::ServicePlan.make(public: true, service: offering)
          offering
        end
        let!(:service_offering_3) { VCAP::CloudController::ServicePlan.make.service }
        let!(:service_offering_4) { VCAP::CloudController::ServicePlan.make.service }

        it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS
      end
    end
  end

  describe 'DELETE /v3/service_offerings/:guid' do
    let(:api_call) { lambda { |user_headers| delete "/v3/service_offerings/#{guid}", nil, user_headers } }

    let(:db_check) {
      lambda do
        get "/v3/service_offerings/#{guid}", {}, admin_headers
        expect(last_response.status).to eq(404), 'expected database entry to be deleted'
      end
    }

    context 'when the service offering does not exist' do
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

    context 'when the service offering exists and has no plans' do
      let!(:service_offering) { VCAP::CloudController::Service.make }
      let(:guid) { service_offering.guid }

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

    context 'when the service offering exists and has public plans' do
      let!(:service_offering) { VCAP::CloudController::ServicePlan.make(public: true).service }
      let(:guid) { service_offering.guid }

      let(:expected_codes_and_responses) do
        Hash.new(code: 403).tap do |h|
          h['admin'] = { code: 422 }
          h['unauthenticated'] = { code: 401 }
        end
      end

      it_behaves_like 'permissions for delete endpoint', COMPLETE_PERMISSIONS
    end

    context 'when the service offering exists and has org-scoped plans' do
      let(:org) { VCAP::CloudController::Organization.make }
      let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false) }
      let(:guid) { service_plan.service.guid }

      before do
        VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan, organization: org)
      end

      let(:expected_codes_and_responses) do
        Hash.new(code: 403).tap do |h|
          h['admin'] = { code: 422 }
          h['no_role'] = { code: 404 }
          h['unauthenticated'] = { code: 401 }
        end
      end

      it_behaves_like 'permissions for delete endpoint', COMPLETE_PERMISSIONS
    end
  end

  def create_offering_json(service_offering)
    {
      'guid' => service_offering.guid,
      'name' => service_offering.label,
      'description' => service_offering.description,
      'available' => service_offering.active,
      'bindable' => true,
      'broker_service_offering_metadata' => service_offering.extra,
      'broker_service_offering_id' => service_offering.unique_id,
      'tags' => [],
      'requires' => [],
      'created_at' => iso8601,
      'updated_at' => iso8601,
      'plan_updateable' => false,
      'shareable' => true,
      'links' => {
        'self' => {
          'href' => %r(#{Regexp.escape(link_prefix)}\/v3\/service_offerings\/#{service_offering.guid})
        },
        'service_plans' => {
          'href' => %r(#{Regexp.escape(link_prefix)}\/v3\/service_plans\?service_offering_guids=#{service_offering.guid})
        },
        'service_broker' => {
          'href' => %r(#{Regexp.escape(link_prefix)}\/v3\/service_brokers\/#{service_offering.service_broker.guid})
        }
      },
      'relationships' => {
        'service_broker' => {
          'data' => {
            'name' => service_offering.service_broker.name,
            'guid' => service_offering.service_broker.guid
          }
        }
      }
    }
  end

  def expect_filtered_service_offerings(filter, list)
    get("/v3/service_offerings?#{filter}", {}, admin_headers)

    expect(last_response).to have_status_code(200)
    expect(parsed_response.fetch('resources').length).to eq(list.length)

    list.each_with_index do |service_offering, index|
      expect(parsed_response['resources'][index]['guid']).to eq(service_offering.guid)
    end
  end
end
