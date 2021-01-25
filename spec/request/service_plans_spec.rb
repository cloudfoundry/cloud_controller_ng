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
      let(:maintenance_info) do
        {
          version: '1.0.0',
          description: 'best plan ever'
        }
      end
      let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, maintenance_info: maintenance_info) }
      let(:guid) { service_plan.guid }

      let(:expected_codes_and_responses) do
        Hash.new(
          code: 200,
          response_object: create_plan_json(service_plan, maintenance_info: maintenance_info)
        )
      end

      it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS

      context 'when the hide_marketplace_from_unauthenticated_users feature flag is enabled' do
        before do
          VCAP::CloudController::FeatureFlag.create(name: 'hide_marketplace_from_unauthenticated_users', enabled: true)
        end

        let(:expected_codes_and_responses) do
          Hash.new({ code: 401 })
        end

        it_behaves_like 'permissions for single object endpoint', UNAUTHENTICATED
      end
    end

    context 'when there is a non-public service plan' do
      context 'global broker' do
        let!(:visibility) { VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan, organization: org) }
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false) }
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
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, service: service_offering) }
        let(:guid) { service_plan.guid }

        let(:expected_codes_and_responses) do
          responses_for_space_restricted_single_endpoint(
            create_plan_json(service_plan),
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

    describe 'fields' do
      let!(:service_plan) { VCAP::CloudController::ServicePlan.make }
      let(:guid) { service_plan.guid }

      it 'can include service broker name and guid' do
        get "/v3/service_plans/#{guid}?fields[service_offering.service_broker]=name,guid", nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['service_brokers']).to have(1).elements
        expect(parsed_response['included']['service_brokers'][0]['guid']).to eq(service_plan.service.service_broker.guid)
        expect(parsed_response['included']['service_brokers'][0]['name']).to eq(service_plan.service.service_broker.name)
      end
    end

    describe 'includes' do
      it 'can include `space.organization`' do
        plan = generate_space_scoped_plan(space)
        guid = plan.guid

        get "/v3/service_plans/#{guid}?include=space.organization", nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['spaces']).to have(1).element
        expect(parsed_response['included']['spaces'][0]['guid']).to eq(space.guid)

        expect(parsed_response['included']['organizations']).to have(1).element
        expect(parsed_response['included']['organizations'][0]['guid']).to eq(space.organization.guid)
      end

      it 'can include `service_offering`' do
        offering = VCAP::CloudController::Service.make
        plan = VCAP::CloudController::ServicePlan.make(service: offering)
        guid = plan.guid

        get "/v3/service_plans/#{guid}?include=service_offering", nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['service_offerings']).to have(1).element
        expect(parsed_response['included']['service_offerings'][0]['guid']).to eq(offering.guid)
      end
    end
  end

  describe 'GET /v3/service_plans' do
    let(:api_call) { lambda { |user_headers| get '/v3/service_plans', nil, user_headers } }

    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/service_plans' }
      let(:message) { VCAP::CloudController::ServicePlansListMessage }
      let(:user_header) { headers_for(user) }
      let(:params) do
        {
          broker_catalog_ids: %w(foo bar),
          names: %w(baz qux),
          organization_guids: %w(quux quuz),
          service_broker_guids: %w(hoge piyo),
          service_broker_names: %w(fuga hogera),
          service_instance_guids: %w(foo bar),
          service_offering_guids: %w(baz qux),
          service_offering_names: %w(quux quuz),
          space_guids: %w(hoge piyo),
          include: 'space.organization',
          available: true,
          per_page: '10',
          page: 2,
          order_by: 'updated_at',
          label_selector: 'foo==bar',
          fields: { 'service_offering.service_broker' => 'name' },
          guids: 'foo,bar',
          created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    context 'no service plans' do
      it 'returns an empty list' do
        get '/v3/service_plans', nil, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources']).to be_empty
      end
    end

    describe 'visibility of service plans' do
      let!(:public_service_plan) { VCAP::CloudController::ServicePlan.make(public: true, name: 'public') }
      let!(:private_service_plan) { VCAP::CloudController::ServicePlan.make(public: false, name: 'private') }
      let!(:space_scoped_service_plan) { generate_space_scoped_plan(space) }
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

    describe 'pagination' do
      let!(:service_plan_1) { VCAP::CloudController::ServicePlan.make(public: true, active: true) }
      let!(:service_plan_2) { VCAP::CloudController::ServicePlan.make(public: true, active: true) }

      let(:resources) { [service_plan_1, service_plan_2] }
      it_behaves_like 'paginated response', '/v3/service_plans'

      it_behaves_like 'paginated fields response', '/v3/service_plans', 'service_offering.service_broker', 'name,guid'
    end

    context 'when the service plans have labels and annotations' do
      let(:service_plan_1) { VCAP::CloudController::ServicePlan.make }
      let(:service_plan_2) { VCAP::CloudController::ServicePlan.make }
      let(:guid_1) { service_plan_1.guid }
      let(:guid_2) { service_plan_2.guid }

      before do
        VCAP::CloudController::ServicePlanLabelModel.make(resource_guid: guid_1, key_name: 'one', value: 'foo')
        VCAP::CloudController::ServicePlanLabelModel.make(resource_guid: guid_2, key_name: 'two', value: 'bar')
        VCAP::CloudController::ServicePlanAnnotationModel.make(resource_guid: guid_1, key: 'alpha', value: 'A1')
        VCAP::CloudController::ServicePlanAnnotationModel.make(resource_guid: guid_2, key: 'beta', value: 'B2')
      end

      it 'displays the metadata correctly' do
        get '/v3/service_plans', nil, admin_headers

        expect(parsed_response['resources'][0].deep_symbolize_keys).to include({
          metadata: {
            labels: { one: 'foo' },
            annotations: { alpha: 'A1' }
          }
        })

        expect(parsed_response['resources'][1].deep_symbolize_keys).to include({
          metadata: {
            labels: { two: 'bar' },
            annotations: { beta: 'B2' }
          }
        })
      end
    end

    describe 'filters' do
      describe 'organization_guids' do
        let(:org_1) { VCAP::CloudController::Organization.make }
        let(:org_2) { VCAP::CloudController::Organization.make }
        let!(:org_plan_1) { VCAP::CloudController::ServicePlan.make(public: false) }
        let!(:org_plan_2) { VCAP::CloudController::ServicePlan.make(public: false) }

        let(:space_1) { VCAP::CloudController::Space.make(organization: org_1) }
        let(:space_2) { VCAP::CloudController::Space.make(organization: org_2) }
        let!(:space_plan_1) { generate_space_scoped_plan(space_1) }
        let!(:space_plan_2) { generate_space_scoped_plan(space_2) }

        let!(:public_plan) { VCAP::CloudController::ServicePlan.make(public: true) }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: org_plan_1, organization: org_1)
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: org_plan_2, organization: org_2)
        end

        it 'selects on org plans, space plans and public plans' do
          get "/v3/service_plans?organization_guids=#{org_1.guid}", {}, admin_headers
          check_filtered_plans(org_plan_1, space_plan_1, public_plan)

          get "/v3/service_plans?organization_guids=#{org_1.guid},#{org_2.guid}", {}, admin_headers
          check_filtered_plans(org_plan_1, org_plan_2, space_plan_1, space_plan_2, public_plan)
        end
      end

      describe 'space_guids' do
        let(:org_1) { VCAP::CloudController::Organization.make }
        let(:org_2) { VCAP::CloudController::Organization.make }
        let!(:org_plan_1) { VCAP::CloudController::ServicePlan.make(public: false) }
        let!(:org_plan_2) { VCAP::CloudController::ServicePlan.make(public: false) }

        let(:space_1) { VCAP::CloudController::Space.make(organization: org_1) }
        let(:space_2) { VCAP::CloudController::Space.make(organization: org_2) }
        let!(:space_plan_1) { generate_space_scoped_plan(space_1) }
        let!(:space_plan_2) { generate_space_scoped_plan(space_2) }

        let!(:public_plan) { VCAP::CloudController::ServicePlan.make(public: true) }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: org_plan_1, organization: org_1)
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: org_plan_2, organization: org_2)
        end

        it 'selects on org plans, space plans and public plans' do
          get "/v3/service_plans?space_guids=#{space_1.guid}", {}, admin_headers
          check_filtered_plans(org_plan_1, space_plan_1, public_plan)

          get "/v3/service_plans?space_guids=#{space_1.guid},#{space_2.guid}", {}, admin_headers
          check_filtered_plans(org_plan_1, org_plan_2, space_plan_1, space_plan_2, public_plan)
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

      describe 'service_instance_guids' do
        let!(:instance_1) { VCAP::CloudController::ManagedServiceInstance.make }
        let!(:instance_2) { VCAP::CloudController::ManagedServiceInstance.make }
        let!(:instance_3) { VCAP::CloudController::ManagedServiceInstance.make }

        it 'filters by service instance guid' do
          filter = [instance_1.guid, instance_3.guid].join(',')
          get "/v3/service_plans?service_instance_guids=#{filter}", {}, admin_headers
          check_filtered_plans(instance_1.service_plan, instance_3.service_plan)
        end
      end

      describe 'label_selector' do
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

    describe 'order_by' do
      it_behaves_like 'list endpoint order_by name', '/v3/service_plans' do
        let(:resource_klass) { VCAP::CloudController::ServicePlan }
      end

      it_behaves_like 'list endpoint order_by timestamps', '/v3/service_plans' do
        let(:resource_klass) { VCAP::CloudController::ServicePlan }
      end
    end

    describe 'includes' do
      it 'can include `space.organization`' do
        space_1 = VCAP::CloudController::Space.make
        space_2 = VCAP::CloudController::Space.make
        generate_space_scoped_plan(space_1)
        generate_space_scoped_plan(space_2)

        get '/v3/service_plans?include=space.organization', nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['spaces']).to have(2).elements
        expect(parsed_response['included']['spaces'][0]['guid']).to eq(space_1.guid)
        expect(parsed_response['included']['spaces'][1]['guid']).to eq(space_2.guid)

        expect(parsed_response['included']['organizations']).to have(2).elements
        expect(parsed_response['included']['organizations'][0]['guid']).to eq(space_1.organization.guid)
        expect(parsed_response['included']['organizations'][1]['guid']).to eq(space_2.organization.guid)
      end

      it 'can include `service_offering`' do
        offering_1 = VCAP::CloudController::Service.make
        offering_2 = VCAP::CloudController::Service.make
        VCAP::CloudController::ServicePlan.make(service: offering_1)
        VCAP::CloudController::ServicePlan.make(service: offering_2)
        VCAP::CloudController::ServicePlan.make(service: offering_2)

        get '/v3/service_plans?include=service_offering', nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['service_offerings']).to have(2).elements
        expect(parsed_response['included']['service_offerings'][0]['guid']).to eq(offering_1.guid)
        expect(parsed_response['included']['service_offerings'][1]['guid']).to eq(offering_2.guid)
      end
    end

    describe 'fields' do
      let!(:plan_1) { VCAP::CloudController::ServicePlan.make }
      let!(:plan_2) { VCAP::CloudController::ServicePlan.make }

      it 'can include service broker name and guid' do
        get '/v3/service_plans?fields[service_offering.service_broker]=name,guid', nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['service_brokers']).to have(2).elements
        expect(parsed_response['included']['service_brokers'][0]['guid']).to eq(plan_1.service.service_broker.guid)
        expect(parsed_response['included']['service_brokers'][0]['name']).to eq(plan_1.service.service_broker.name)
        expect(parsed_response['included']['service_brokers'][1]['guid']).to eq(plan_2.service.service_broker.guid)
        expect(parsed_response['included']['service_brokers'][1]['name']).to eq(plan_2.service.service_broker.name)
      end
    end

    describe 'eager loading' do
      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::ServicePlanListFetcher).to receive(:fetch).with(
          an_instance_of(VCAP::CloudController::ServicePlansListMessage),
          hash_including(eager_loaded_associations: [:labels, :annotations, { service: :service_broker }])
        ).and_call_original

        get '/v3/service_plans', nil, admin_headers
        expect(last_response).to have_status_code(200)
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::ServicePlan }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/service_plans?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
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
      let(:email) { Sham.email }
      let(:admin_headers) { admin_headers_for(user, email: email) }

      it 'emits an audit event' do
        delete "/v3/service_plans/#{service_plan.guid}", nil, admin_headers

        expect([
          { type: 'audit.service_plan.delete', actor: email },
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

  def create_plan_json(service_plan, labels: {}, annotations: {}, maintenance_info: {})
    plan = {
      guid: service_plan.guid,
      created_at: iso8601,
      updated_at: iso8601,
      visibility_type: service_plan.visibility_type,
      available: match(boolean),
      name: service_plan.name,
      free: match(boolean),
      costs: [],
      description: service_plan.description,
      broker_catalog: {
        id: service_plan.unique_id,
        metadata: {},
        maximum_polling_duration: nil,
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
      maintenance_info: maintenance_info,
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

  def generate_space_scoped_plan(space)
    broker = VCAP::CloudController::ServiceBroker.make(space: space)
    offering = VCAP::CloudController::Service.make(service_broker: broker)
    VCAP::CloudController::ServicePlan.make(service: offering)
  end
end
