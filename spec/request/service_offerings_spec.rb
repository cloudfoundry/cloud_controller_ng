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
          responses_for_space_restricted_single_endpoint(
            create_offering_json(service_offering),
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

    context 'when the service offering has labels and annotations' do
      let(:service_offering) { VCAP::CloudController::ServicePlan.make.service }
      let(:guid) { service_offering.guid }

      before do
        VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: guid, key_name: 'one', value: 'foo')
        VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: guid, key_name: 'two', value: 'bar')
        VCAP::CloudController::ServiceOfferingAnnotationModel.make(resource_guid: guid, key: 'alpha', value: 'A1')
        VCAP::CloudController::ServiceOfferingAnnotationModel.make(resource_guid: guid, key: 'beta', value: 'B2')
      end

      it 'displays the metadata correctly' do
        get "/v3/service_offerings/#{guid}", nil, admin_headers

        expect(parsed_response.deep_symbolize_keys).to include({
          metadata: {
            labels: {
              one: 'foo',
              two: 'bar',
            },
            annotations: {
              alpha: 'A1',
              beta: 'B2',
            }
          }
        })
      end
    end

    describe 'fields' do
      let!(:service_offering) { VCAP::CloudController::Service.make }

      it 'can include service broker name and guid' do
        get "/v3/service_offerings/#{service_offering.guid}?fields[service_broker]=name,guid", nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['service_brokers']).to have(1).elements
        expect(parsed_response['included']['service_brokers'][0]['guid']).to eq(service_offering.service_broker.guid)
        expect(parsed_response['included']['service_brokers'][0]['name']).to eq(service_offering.service_broker.name)
      end
    end
  end

  describe 'GET /v3/service_offerings' do
    let(:api_call) { lambda { |user_headers| get '/v3/service_offerings', nil, user_headers } }

    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/service_offerings' }
      let(:message) { VCAP::CloudController::ServiceOfferingsListMessage }
      let(:user_header) { headers_for(user) }
      let(:params) do
        {
          available: true,
          service_broker_guids: %w(foo bar),
          service_broker_names: %w(baz qux),
          names: %w(quux quuz),
          space_guids: %w(hoge piyo),
          organization_guids: %w(fuga hogera),
          per_page: '10',
          page: 2,
          order_by: 'updated_at',
          label_selector: 'foo==bar',
          fields: { 'service_broker' => 'name' },
          guids: 'foo,bar',
          created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    context 'no service offerings' do
      it 'returns an empty list' do
        get '/v3/service_offerings', nil, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources']).to be_empty
      end
    end

    describe 'visibility of service offerings' do
      let!(:public_service_offering) { VCAP::CloudController::ServicePlan.make(public: true, name: 'public').service }
      let!(:private_service_offering) { VCAP::CloudController::ServicePlan.make(public: false, name: 'private').service }
      let!(:space_scoped_service_offering) do
        broker = VCAP::CloudController::ServiceBroker.make(space: space)
        VCAP::CloudController::Service.make(service_broker: broker)
      end
      let!(:org_restricted_service_offering) do
        service_plan = VCAP::CloudController::ServicePlan.make(public: false)
        VCAP::CloudController::ServicePlanVisibility.make(organization: org, service_plan: service_plan)
        service_plan.service
      end

      let(:all_offerings_response) do
        {
          code: 200,
          response_objects: [
            create_offering_json(public_service_offering),
            create_offering_json(private_service_offering),
            create_offering_json(space_scoped_service_offering),
            create_offering_json(org_restricted_service_offering),
          ]
        }
      end

      let(:org_offerings_response) do
        {
          code: 200,
          response_objects: [
            create_offering_json(public_service_offering),
            create_offering_json(org_restricted_service_offering),
          ]
        }
      end

      let(:space_offerings_response) do
        {
          code: 200,
          response_objects: [
            create_offering_json(public_service_offering),
            create_offering_json(space_scoped_service_offering),
            create_offering_json(org_restricted_service_offering),
          ]
        }
      end

      let(:expected_codes_and_responses) do
        Hash.new(
          code: 200,
          response_objects: [
            create_offering_json(public_service_offering),
          ]
        ).tap do |h|
          h['admin'] = all_offerings_response
          h['admin_read_only'] = all_offerings_response
          h['global_auditor'] = all_offerings_response
          h['org_manager'] = org_offerings_response
          h['org_billing_manager'] = org_offerings_response
          h['org_auditor'] = org_offerings_response
          h['space_developer'] = space_offerings_response
          h['space_manager'] = space_offerings_response
          h['space_auditor'] = space_offerings_response
        end
      end

      it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS
    end

    describe 'pagination' do
      let!(:service_offering_1) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }
      let!(:service_offering_2) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }

      let(:resources) { [service_offering_1, service_offering_2] }
      it_behaves_like 'paginated response', '/v3/service_offerings'

      it_behaves_like 'paginated fields response', '/v3/service_offerings', 'service_broker', 'guid,name'
    end

    context 'when the service offerings have labels and annotations' do
      let(:service_offering_1) { VCAP::CloudController::ServicePlan.make.service }
      let(:service_offering_2) { VCAP::CloudController::ServicePlan.make.service }
      let(:guid_1) { service_offering_1.guid }
      let(:guid_2) { service_offering_2.guid }

      before do
        VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: guid_1, key_name: 'one', value: 'foo')
        VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: guid_2, key_name: 'two', value: 'bar')
        VCAP::CloudController::ServiceOfferingAnnotationModel.make(resource_guid: guid_1, key: 'alpha', value: 'A1')
        VCAP::CloudController::ServiceOfferingAnnotationModel.make(resource_guid: guid_2, key: 'beta', value: 'B2')
      end

      it 'displays the metadata correctly' do
        get '/v3/service_offerings', nil, admin_headers

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
      describe 'available' do
        let(:api_call) { lambda { |user_headers| get "/v3/service_offerings?available=#{available}", nil, user_headers } }

        let!(:service_offering_available) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }
        let!(:service_offering_unavailable) do
          offering = VCAP::CloudController::Service.make(active: false)
          VCAP::CloudController::ServicePlan.make(public: true, active: true, service: offering)
          offering
        end

        it 'filters for available offerings' do
          expect_filtered_service_offerings(
            'available=true',
            [service_offering_available],
          )
        end

        it 'filters for unavailable offerings' do
          expect_filtered_service_offerings(
            'available=false',
            [service_offering_unavailable],
          )
        end
      end

      describe 'guids' do
        let!(:service_broker_1) { VCAP::CloudController::ServiceBroker.make(space: space) }
        let!(:service_offering_1) { VCAP::CloudController::Service.make(service_broker: service_broker_1) }

        let(:space_2) { VCAP::CloudController::Space.make(organization: org) }
        let(:service_broker_2) { VCAP::CloudController::ServiceBroker.make(space: space_2) }
        let!(:service_offering_2) { VCAP::CloudController::Service.make(service_broker: service_broker_2) }

        let(:space_3) { VCAP::CloudController::Space.make(organization: org) }
        let(:service_broker_3) { VCAP::CloudController::ServiceBroker.make(space: space_3) }
        let!(:service_offering_3) { VCAP::CloudController::Service.make(service_broker: service_broker_3) }

        let!(:public_plan) { VCAP::CloudController::ServicePlan.make(public: true) }
        let!(:public_service_offering) { public_plan.service }

        let!(:guids) { [service_offering_1.guid, service_offering_2.guid] }

        it 'returns the right offerings' do
          expect_filtered_service_offerings(
            "guids=#{guids.join(',')}",
            [service_offering_1, service_offering_2]
          )
        end
      end

      describe 'space_guids' do
        let(:org_1) { VCAP::CloudController::Organization.make }
        let(:org_2) { VCAP::CloudController::Organization.make }
        let!(:org_plan_1) { VCAP::CloudController::ServicePlan.make(public: false) }
        let!(:org_plan_2) { VCAP::CloudController::ServicePlan.make(public: false) }
        let!(:org_offering_1) { org_plan_1.service }
        let!(:org_offering_2) { org_plan_2.service }

        let(:space_1) { VCAP::CloudController::Space.make(organization: org_1) }
        let(:space_2) { VCAP::CloudController::Space.make(organization: org_2) }
        let!(:space_offering_1) { generate_space_scoped_offering(space_1) }
        let!(:space_offering_2) { generate_space_scoped_offering(space_2) }

        let!(:public_offering) { VCAP::CloudController::ServicePlan.make(public: true).service }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: org_plan_1, organization: org_1)
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: org_plan_2, organization: org_2)
        end

        it 'selects on space plans, org plans, and public plans' do
          expect_filtered_service_offerings(
            "space_guids=#{space_1.guid}",
            [org_offering_1, space_offering_1, public_offering]
          )

          expect_filtered_service_offerings(
            "space_guids=#{space_1.guid},#{space_2.guid}",
            [org_offering_1, org_offering_2, space_offering_1, space_offering_2, public_offering]
          )
        end
      end

      describe 'organization_guids' do
        let(:org_1) { VCAP::CloudController::Organization.make }
        let(:org_2) { VCAP::CloudController::Organization.make }
        let!(:org_plan_1) { VCAP::CloudController::ServicePlan.make(public: false) }
        let!(:org_plan_2) { VCAP::CloudController::ServicePlan.make(public: false) }
        let!(:org_offering_1) { org_plan_1.service }
        let!(:org_offering_2) { org_plan_2.service }

        let(:space_1) { VCAP::CloudController::Space.make(organization: org_1) }
        let(:space_2) { VCAP::CloudController::Space.make(organization: org_2) }
        let!(:space_offering_1) { generate_space_scoped_offering(space_1) }
        let!(:space_offering_2) { generate_space_scoped_offering(space_2) }

        let!(:public_offering) { VCAP::CloudController::ServicePlan.make(public: true).service }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: org_plan_1, organization: org_1)
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: org_plan_2, organization: org_2)
        end

        it 'selects on space plans, org plans, and public plans' do
          expect_filtered_service_offerings(
            "organization_guids=#{org_1.guid}",
            [org_offering_1, space_offering_1, public_offering]
          )

          expect_filtered_service_offerings(
            "organization_guids=#{org_1.guid},#{org_2.guid}",
            [org_offering_1, org_offering_2, space_offering_1, space_offering_2, public_offering]
          )
        end
      end

      describe 'service_broker_guids' do
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
        let(:service_broker_guids) { [service_broker.guid, service_offering_3.service_broker.guid] }

        it 'filters by broker guid' do
          expect_filtered_service_offerings(
            "service_broker_guids=#{service_broker_guids.join(',')}",
            [
              service_offering_1,
              service_offering_2,
              service_offering_3,
            ],
          )
        end
      end

      describe 'service_broker_names' do
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
        let(:service_broker_names) { [service_broker.name, service_offering_4.service_broker.name] }

        it 'filters by broker name' do
          expect_filtered_service_offerings(
            "service_broker_names=#{service_broker_names.join(',')}",
            [
              service_offering_1,
              service_offering_2,
              service_offering_4,
            ],
          )
        end
      end

      describe 'names' do
        let!(:service_offering_1) { VCAP::CloudController::ServicePlan.make(public: true).service }
        let!(:service_offering_2) { VCAP::CloudController::ServicePlan.make(public: true).service }
        let!(:service_offering_3) { VCAP::CloudController::ServicePlan.make(public: true).service }
        let!(:service_offering_4) { VCAP::CloudController::ServicePlan.make(public: true).service }
        let(:service_offering_names) { [service_offering_1.name, service_offering_4.name] }

        it 'filters by name' do
          expect_filtered_service_offerings(
            "names=#{service_offering_names.join(',')}",
            [
              service_offering_1,
              service_offering_4,
            ],
          )
        end
      end

      describe 'label_selector' do
        let!(:service_offering_1) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }
        let!(:service_offering_2) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }
        let!(:service_offering_3) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }

        before do
          VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: service_offering_1.guid, key_name: 'flavor', value: 'orange')
          VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: service_offering_2.guid, key_name: 'flavor', value: 'orange')
          VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: service_offering_3.guid, key_name: 'flavor', value: 'apple')
        end

        it 'filters by label' do
          expect_filtered_service_offerings(
            'label_selector=flavor=orange',
            [
              service_offering_1,
              service_offering_2,
            ],
          )
        end
      end
    end

    describe 'order_by' do
      context 'name' do # can't use shared example as it sets 'name' rather than 'label'
        let!(:resource_1) { VCAP::CloudController::Service.make(guid: '1', label: 'flopsy') }
        let!(:resource_2) { VCAP::CloudController::Service.make(guid: '2', label: 'mopsy') }
        let!(:resource_3) { VCAP::CloudController::Service.make(guid: '3', label: 'cottontail') }
        let!(:resource_4) { VCAP::CloudController::Service.make(guid: '4', label: 'peter') }

        it 'sorts ascending' do
          get('/v3/service_offerings?order_by=name', nil, admin_headers)
          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'][0]['name']).to eq('cottontail')
          expect(parsed_response['resources'][1]['name']).to eq('flopsy')
          expect(parsed_response['resources'][2]['name']).to eq('mopsy')
          expect(parsed_response['resources'][3]['name']).to eq('peter')
        end

        it 'sorts descending' do
          get('/v3/service_offerings?order_by=-name', nil, admin_headers)
          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'][0]['name']).to eq('peter')
          expect(parsed_response['resources'][1]['name']).to eq('mopsy')
          expect(parsed_response['resources'][2]['name']).to eq('flopsy')
          expect(parsed_response['resources'][3]['name']).to eq('cottontail')
        end

        it 'builds the right links' do
          get('/v3/service_offerings?order_by=name&per_page=2', nil, admin_headers)
          expect(last_response).to have_status_code(200)
          expect(parsed_response['pagination']['first']['href']).to include('order_by=%2Bname')
          expect(parsed_response['pagination']['last']['href']).to include('order_by=%2Bname')
          expect(parsed_response['pagination']['next']['href']).to include('order_by=%2Bname')
        end
      end

      it_behaves_like 'list endpoint order_by timestamps', '/v3/service_offerings' do
        let(:resource_klass) { VCAP::CloudController::Service }
      end
    end

    describe 'fields' do
      let!(:service_1) { VCAP::CloudController::Service.make }
      let!(:service_2) { VCAP::CloudController::Service.make }

      it 'can include service broker name and guid' do
        get '/v3/service_offerings?fields[service_broker]=name,guid', nil, admin_headers
        expect(last_response).to have_status_code(200)

        expect(parsed_response['included']['service_brokers']).to have(2).elements
        expect(parsed_response['included']['service_brokers'][0]['guid']).to eq(service_1.service_broker.guid)
        expect(parsed_response['included']['service_brokers'][0]['name']).to eq(service_1.service_broker.name)
        expect(parsed_response['included']['service_brokers'][1]['guid']).to eq(service_2.service_broker.guid)
        expect(parsed_response['included']['service_brokers'][1]['name']).to eq(service_2.service_broker.name)
      end
    end

    describe 'eager loading' do
      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::ServiceOfferingListFetcher).to receive(:fetch).with(
          an_instance_of(VCAP::CloudController::ServiceOfferingsListMessage),
          hash_including(eager_loaded_associations: [:labels, :annotations, :service_broker])
        ).and_call_original

        get '/v3/service_offerings', nil, admin_headers
        expect(last_response).to have_status_code(200)
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::Service }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/service_offerings?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end
  end

  describe 'DELETE /v3/service_offerings/:guid' do
    let(:api_call) { lambda { |user_headers| delete "/v3/service_offerings/#{guid}", nil, user_headers } }

    let(:db_check) {
      lambda do
        expect(VCAP::CloudController::Service.all).to be_empty
      end
    }

    context 'when the service offering does not exist' do
      let(:guid) { 'non-existing-guid' }

      let(:expected_codes_and_responses) do
        Hash.new(code: 404).tap do |h|
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

      context 'deleting metadata' do
        it_behaves_like 'resource with metadata' do
          let(:resource) { service_offering }
          let(:api_call) do
            -> { delete "/v3/service_offerings/#{service_offering.guid}", nil, admin_headers }
          end
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

    context 'when the service offering is from a space-scoped service broker' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: space) }
      let!(:service_offering) { VCAP::CloudController::Service.make(service_broker: service_broker) }
      let(:guid) { service_offering.guid }

      before do
        # Being a SpaceDeveloper in another space should make no difference
        alternative_org = VCAP::CloudController::Organization.make
        alternative_org.add_user(user)
        alternative_space = VCAP::CloudController::Space.make(organization: alternative_org)
        alternative_space.add_developer(user)
      end

      let(:expected_codes_and_responses) do
        Hash.new(code: 404).tap do |h|
          h['admin'] = { code: 204 }
          h['admin_read_only'] = { code: 403 }
          h['global_auditor'] = { code: 403 }
          h['space_manager'] = { code: 403 }
          h['space_auditor'] = { code: 403 }
          h['space_developer'] = { code: 204 }
          h['unauthenticated'] = { code: 401 }
        end
      end

      it_behaves_like 'permissions for delete endpoint', COMPLETE_PERMISSIONS
    end

    describe 'audit events' do
      let(:email) { Sham.email }
      let(:admin_headers) { admin_headers_for(user, email: email) }
      let(:service_offering) { VCAP::CloudController::Service.make }

      it 'emits an audit event' do
        delete "/v3/service_offerings/#{service_offering.guid}", nil, admin_headers

        expect([
          { type: 'audit.service.delete', actor: email },
        ]).to be_reported_as_events
      end
    end

    context 'when purge=true' do
      let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }
      let!(:service_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: service_instance) }
      let!(:service_key) { VCAP::CloudController::ServiceKey.make(service_instance: service_instance) }
      let(:guid) { service_instance.service_plan.service.guid }
      let(:email) { Sham.email }
      let(:admin_header) { admin_headers_for(user, email: email) }

      it 'deletes the service offering and its dependencies' do
        delete "/v3/service_offerings/#{guid}?purge=true", nil, admin_header

        expect(last_response).to have_status_code(204)
        expect(VCAP::CloudController::Service.all).to be_empty
        expect(VCAP::CloudController::ServicePlan.all).to be_empty
        expect(VCAP::CloudController::ManagedServiceInstance.all).to be_empty
        expect(VCAP::CloudController::ServiceBinding.all).to be_empty
      end

      it 'emits audit events for all the deleted resources' do
        delete "/v3/service_offerings/#{guid}?purge=true", nil, admin_header

        expect([
          { type: 'audit.service.delete', actor: email },
          { type: 'audit.service_instance.purge', actor: email },
          { type: 'audit.service_binding.delete', actor: email },
          { type: 'audit.service_key.delete', actor: email },
        ]).to be_reported_as_events
      end
    end
  end

  describe 'PATCH /v3/service_offerings/:guid' do
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

    it 'can update labels and annotations' do
      service_offering = VCAP::CloudController::ServicePlan.make(public: true, active: true).service

      patch "/v3/service_offerings/#{service_offering.guid}", update_request_body.to_json, admin_headers

      expect(last_response).to have_status_code(200)
      expect(parsed_response.deep_symbolize_keys).to include(update_request_body)
    end

    context 'when some labels are invalid' do
      let(:labels) { { potato: 'sweet invalid potato' } }
      let!(:service_offering) { VCAP::CloudController::Service.make(active: true) }

      it 'returns a proper failure' do
        patch "/v3/service_offerings/#{service_offering.guid}", update_request_body.to_json, admin_headers

        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors'][0]['detail']).to match(/Metadata [\w\s]+ error/)
      end
    end

    context 'when some annotations are invalid' do
      let(:annotations) { { '/style' => 'sweet invalid style' } }
      let!(:service_offering) { VCAP::CloudController::Service.make(active: true) }

      it 'returns a proper failure' do
        patch "/v3/service_offerings/#{service_offering.guid}", update_request_body.to_json, admin_headers

        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors'][0]['detail']).to match(/Metadata [\w\s]+ error/)
      end
    end

    context 'when the service offering does not exist' do
      it 'returns a not found error' do
        patch '/v3/service_offerings/some-invalid-guid', update_request_body.to_json, admin_headers

        expect(last_response).to have_status_code(404)
      end
    end

    context 'permissions' do
      let(:api_call) { lambda { |user_headers| patch "/v3/service_offerings/#{guid}", update_request_body.to_json, user_headers } }
      let(:guid) { service_offering.guid }

      context 'when the service offering exists and has no plans' do
        let!(:service_offering) { VCAP::CloudController::Service.make(active: true) }

        let(:expected_codes_and_responses) do
          Hash.new(code: 404).tap do |h|
            h['admin'] = {
              code: 200,
              response_object: create_offering_json(service_offering, labels: labels, annotations: annotations)
            }
            h['admin_read_only'] = { code: 403 }
            h['global_auditor'] = { code: 403 }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end

      context 'when the service offering exists and has public plans' do
        let!(:service_offering) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }

        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['admin'] = {
              code: 200,
              response_object: create_offering_json(service_offering, labels: labels, annotations: annotations)
            }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end

      context 'when the service offering exists and has org-scoped plans' do
        let!(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false) }
        let!(:service_offering) { service_plan.service }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan, organization: org)
        end

        let(:expected_codes_and_responses) do
          Hash.new(code: 403).tap do |h|
            h['admin'] = {
              code: 200,
              response_object: create_offering_json(service_offering, labels: labels, annotations: annotations)
            }
            h['no_role'] = { code: 404 }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end

      context 'when the service offering is from a space-scoped service broker' do
        let(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: space) }
        let!(:service_offering) { VCAP::CloudController::Service.make(service_broker: service_broker) }

        before do
          # Being a SpaceDeveloper in another space should make no difference
          alternative_org = VCAP::CloudController::Organization.make
          alternative_org.add_user(user)
          alternative_space = VCAP::CloudController::Space.make(organization: alternative_org)
          alternative_space.add_developer(user)
        end

        let(:expected_codes_and_responses) do
          Hash.new(code: 404).tap do |h|
            h['admin'] = {
              code: 200,
              response_object: create_offering_json(service_offering, labels: labels, annotations: annotations)
            }
            h['admin_read_only'] = { code: 403 }
            h['global_auditor'] = { code: 403 }
            h['space_manager'] = { code: 403 }
            h['space_auditor'] = { code: 403 }
            h['space_developer'] = {
              code: 200,
              response_object: create_offering_json(service_offering, labels: labels, annotations: annotations)
            }
            h['unauthenticated'] = { code: 401 }
          end
        end

        it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
      end
    end
  end

  def create_offering_json(service_offering, labels: {}, annotations: {})
    {
      'guid' => service_offering.guid,
      'name' => service_offering.label,
      'description' => service_offering.description,
      'available' => service_offering.active,
      'tags' => [],
      'requires' => [],
      'created_at' => iso8601,
      'updated_at' => iso8601,
      'shareable' => true,
      'documentation_url' => 'https://some.url.for.docs/',
      'broker_catalog' => {
        'id' => service_offering.unique_id,
        'metadata' => JSON.parse(service_offering.extra),
        'features' => {
          'plan_updateable' => false,
          'bindable' => true,
          'instances_retrievable' => false,
          'bindings_retrievable' => false,
          'allow_context_updates' => false,
        }
      },
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
            'guid' => service_offering.service_broker.guid
          }
        }
      },
      'metadata' => {
        'labels' => labels,
        'annotations' => annotations
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

  def generate_space_scoped_offering(space)
    broker = VCAP::CloudController::ServiceBroker.make(space: space)
    VCAP::CloudController::Service.make(service_broker: broker)
  end
end
