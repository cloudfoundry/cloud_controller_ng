require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServicePlansController, :services do
    shared_examples 'enumerate and read plan only' do |perm_name|
      include_examples 'permission enumeration', perm_name,
                       name: 'service plan',
                       path: '/v2/service_plans',
                       permissions_overlap: true,
                       enumerate: 7
    end

    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:active) }
      it { expect(described_class).to be_queryable_by(:service_guid) }
      it { expect(described_class).to be_queryable_by(:service_instance_guid) }
      it { expect(described_class).to be_queryable_by(:service_broker_guid) }
      it { expect(described_class).to be_queryable_by(:unique_id) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).
          to have_creatable_attributes(
            {
              name: { type: 'string', required: true },
              free: { type: 'bool', required: true },
              description: { type: 'string', required: true },
              extra: { type: 'string' },
              unique_id: { type: 'string' },
              public: { type: 'bool', default: true },
              service_guid: { type: 'string', required: true },
              service_instance_guids: { type: '[string]' },
            }
           )
      end

      it do
        expect(described_class).
          to have_updatable_attributes(
            {
              name: { type: 'string' },
              free: { type: 'bool' },
              description: { type: 'string' },
              extra: { type: 'string' },
              unique_id: { type: 'string' },
              public: { type: 'bool' },
              service_guid: { type: 'string' },
              service_instance_guids: { type: '[string]' },
            })
      end
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        5.times { ServicePlan.make }
        @obj_a = ServicePlan.make
        @obj_b = ServicePlan.make
      end

      describe 'Org Level Permissions' do
        describe 'OrgManager' do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples 'enumerate and read plan only', 'OrgManager'
        end

        describe 'OrgUser' do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples 'enumerate and read plan only', 'OrgUser'
        end

        describe 'BillingManager' do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples 'enumerate and read plan only', 'BillingManager'
        end

        describe 'Auditor' do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples 'enumerate and read plan only', 'Auditor'
        end
      end

      describe 'App Space Level Permissions' do
        describe 'SpaceManager' do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples 'enumerate and read plan only', 'SpaceManager'
        end

        describe 'Developer' do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples 'enumerate and read plan only', 'Developer'
        end

        describe 'SpaceAuditor' do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples 'enumerate and read plan only', 'SpaceAuditor'
        end
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes({ service_instances: [:get, :put, :delete] })
      end
    end

    let(:developer) { make_developer_for_space(Space.make) }

    describe 'non public service plans' do
      let!(:private_plan) { ServicePlan.make(public: false) }
      let(:plan_guids) do
        decoded_response.fetch('resources').collect do |r|
          r.fetch('metadata').fetch('guid')
        end
      end

      before { set_current_user(developer) }

      it 'is not visible to users from normal organization' do
        get '/v2/service_plans'
        expect(plan_guids).not_to include(private_plan.guid)
      end

      it 'is visible to users from organizations with access to the plan' do
        organization = developer.organizations.first
        VCAP::CloudController::ServicePlanVisibility.create(
          organization: organization,
          service_plan: private_plan,
        )
        get '/v2/service_plans'
        expect(plan_guids).to include(private_plan.guid)
      end

      it 'is visible to cf admin' do
        set_current_user_as_admin
        get '/v2/service_plans'
        expect(plan_guids).to include(private_plan.guid)
      end
    end

    describe 'GET', '/v2/service_plans/:guid' do
      let(:service_plan) { ServicePlan.make }

      it 'returns the plan' do
        set_current_user_as_admin

        get "/v2/service_plans/#{service_plan.guid}"

        expect(last_response.status).to eq 200

        metadata = decoded_response.fetch('metadata')
        expect(metadata['guid']).to eq service_plan.guid

        entity = decoded_response.fetch('entity')
        expect(entity['service_guid']).to eq service_plan.service.guid
      end

      it 'returns an empty schema for service instance creation' do
        set_current_user_as_admin

        get "/v2/service_plans/#{service_plan.guid}"

        expect(last_response.status).to eq 200

        schemas = decoded_response.fetch('entity')['schemas']

        expect(schemas).to_not be_nil
        expect(schemas).to eq({ 'service_instance' => { 'create' => { 'parameters' => {} }, 'update' => { 'parameters' => {} } } })
      end

      context 'when the plan does not set bindable' do
        let(:service_plan) { ServicePlan.make(bindable: nil) }

        it 'inherits bindable from the service' do
          set_current_user_as_admin

          get "/v2/service_plans/#{service_plan.guid}"

          expect(last_response.status).to eq 200

          bindable = decoded_response.fetch('entity')['bindable']
          expect(bindable).to_not be_nil
          expect(bindable).to eq service_plan.service.bindable
        end
      end

      context 'non-admin user' do
        let(:user) { User.make }

        before do
          set_current_user(user)
        end

        it 'returns the plan' do
          get "/v2/service_plans/#{service_plan.guid}"
          expect(last_response.status).to eq 200

          metadata = decoded_response.fetch('metadata')
          expect(metadata['guid']).to eq service_plan.guid

          entity = decoded_response.fetch('entity')
          expect(entity['service_guid']).to eq service_plan.service.guid
        end

        context 'when the plan is inactive' do
          let(:inactive_plan) { ServicePlan.make(:v2, active: false, public: true) }

          it 'returns a 403' do
            get "/v2/service_plans/#{inactive_plan.guid}"
            expect(last_response.status).to eq 403
          end

          context 'and the user has a service instance associated with that plan' do
            let(:organization) { Organization.make }
            let(:space) { Space.make(organization: organization) }

            before do
              space.organization.add_user(user)
              space.add_developer(user)
              set_current_user_as_admin
            end

            it 'returns the plan' do
              broker = ServiceBroker.make
              service = Service.make(service_broker: broker)
              service_plan = ServicePlan.make(service: service, public: false, active: false)
              ManagedServiceInstance.make(space: space, service_plan: service_plan)
              service_plan.reload

              set_current_user(user)
              get "/v2/service_plans/#{service_plan.guid}"
              expect(last_response.status).to eq(200), "Expected response to be 200: #{last_response.body}"

              entity = decoded_response.fetch('entity')
              expect(entity['public']).to be_falsey

              metadata = decoded_response.fetch('metadata')
              expect(metadata['guid']).to eq service_plan.guid

              entity = decoded_response.fetch('entity')
              expect(entity['service_guid']).to eq service_plan.service.guid
            end

            it 'returns the unbindable plan' do
              broker = ServiceBroker.make
              service = Service.make(:v2, service_broker: broker)
              service_plan = ServicePlan.make(:v2, service: service, public: true, active: true)
              ManagedServiceInstance.make(:v2, space: space, service_plan: service_plan)
              service_plan.update(public: false)
              service_plan.reload

              set_current_user(user)
              get "/v2/service_plans/#{service_plan.guid}"
              expect(last_response.status).to eq 200

              expect(decoded_response.fetch('entity')['public']).to be_falsey

              metadata = decoded_response.fetch('metadata')
              expect(metadata['guid']).to eq service_plan.guid

              entity = decoded_response.fetch('entity')
              expect(entity['service_guid']).to eq service_plan.service.guid
            end
          end
        end
      end
    end

    describe 'GET', '/v2/service_plans' do
      before do
        @services = {
          public:
            [
              ServicePlan.make(:v2, active: true, public: true),
              ServicePlan.make(:v2, active: true, public: true),
              ServicePlan.make(:v2, active: false, public: true)
            ],
          private: [
            ServicePlan.make(:v2, active: true, public: false),
            ServicePlan.make(:v2, active: false, public: false)
          ]
        }
      end

      context 'as a space developer' do
        context 'with private service brokers' do
          it 'returns service plans from private brokers that are in the same space as the user' do
            user = User.make
            space = Space.make
            space.organization.add_user user
            private_broker = ServiceBroker.make(space: space)
            service = Service.make(service_broker: private_broker)
            space.add_developer(user)
            private_broker_service_plan = ServicePlan.make(service: service, public: false)

            set_current_user(user)
            get '/v2/service_plans'
            expect(last_response.status).to eq 200

            returned_plan_guids = decoded_response.fetch('resources').map do |res|
              res['metadata']['guid']
            end

            expect(returned_plan_guids).to include(private_broker_service_plan.guid)
          end
        end

        context 'when a service instance is associated with an inactive plan' do
          it 'does not list the inactive service plan' do
            user = User.make
            space = Space.make
            service = Service.make
            service_plan = ServicePlan.make(service: service, public: true, active: true)
            ManagedServiceInstance.make(service_plan: service_plan)
            service_plan.update(public: false)
            service_plan.reload

            space.organization.add_user(user)
            space.add_developer(user)

            set_current_user(user)
            get '/v2/service_plans'
            expect(last_response.status).to eq 200

            returned_plan_guids = decoded_response.fetch('resources').map do |res|
              res['metadata']['guid']
            end

            expect(returned_plan_guids).not_to include(service_plan.guid)
          end
        end
      end

      context 'as an admin' do
        let(:different_service) { Service.make(service_broker: ServiceBroker.make) }
        let(:different_service_plan) { ServicePlan.make }
        before do
          set_current_user_as_admin
          different_service_plan.service = different_service
        end

        it 'displays all service plans' do
          get '/v2/service_plans'
          expect(last_response.status).to eq 200

          plans = ServicePlan.all
          expected_plan_guids = plans.map(&:guid)
          expected_service_guids = plans.map(&:service).map(&:guid).uniq

          returned_plan_guids = decoded_response.fetch('resources').map do |res|
            res['metadata']['guid']
          end

          returned_service_guids = decoded_response.fetch('resources').map do |res|
            res['entity']['service_guid']
          end

          expect(returned_plan_guids).to match_array expected_plan_guids
          expect(returned_service_guids).to match_array expected_service_guids
          expect(returned_plan_guids).to include(different_service_plan.guid)
        end

        it 'can query by service plan guid' do
          service = @services[:public][0].service
          get "/v2/service_plans?q=service_guid:#{service.guid}"
          expect(last_response.status).to eq 200

          expected_plan_guids = service.service_plans.map(&:guid)
          expected_service_guids = [service.guid]

          returned_plan_guids = decoded_response.fetch('resources').map do |res|
            res['metadata']['guid']
          end

          returned_service_guids = decoded_response.fetch('resources').map do |res|
            res['entity']['service_guid']
          end

          expect(returned_plan_guids).to match_array expected_plan_guids
          expect(returned_service_guids).to match_array expected_service_guids
          expect(returned_plan_guids).not_to include(different_service_plan.guid)
        end

        it 'can query by service broker guid using ":"' do
          service = @services[:public][0].service
          get "/v2/service_plans?q=service_broker_guid:#{service.service_broker.guid}"
          expect(last_response.status).to eq 200

          expected_plan_guids = service.service_plans.map(&:guid)
          expected_service_guids = [service.guid]

          returned_plan_guids = decoded_response.fetch('resources').map do |res|
            res['metadata']['guid']
          end

          returned_service_guids = decoded_response.fetch('resources').map do |res|
            res['entity']['service_guid']
          end

          expect(returned_plan_guids).to match_array expected_plan_guids
          expect(returned_service_guids).to match_array expected_service_guids
          expect(returned_plan_guids).not_to include(different_service_plan.guid)
        end

        it 'can query by service broker guid using "IN"' do
          service = @services[:public][0].service
          get "/v2/service_plans?q=service_broker_guid%20IN%20#{service.service_broker.guid}"
          expect(last_response.status).to eq 200

          expected_plan_guids = service.service_plans.map(&:guid)
          expected_service_guids = [service.guid]

          returned_plan_guids = decoded_response.fetch('resources').map do |res|
            res['metadata']['guid']
          end

          returned_service_guids = decoded_response.fetch('resources').map do |res|
            res['entity']['service_guid']
          end

          expect(returned_plan_guids).to match_array expected_plan_guids
          expect(returned_service_guids).to match_array expected_service_guids
          expect(returned_plan_guids).not_to include(different_service_plan.guid)
        end
      end

      context 'when the user is not logged in' do
        before { set_current_user(nil) }

        it 'returns plans that are public and active' do
          get '/v2/service_plans'
          expect(last_response.status).to eq 200

          public_and_active_plans = ServicePlan.where(active: true, public: true).all
          expected_plan_guids = public_and_active_plans.map(&:guid)
          expected_service_guids = public_and_active_plans.map(&:service).map(&:guid).uniq

          returned_plan_guids = decoded_response.fetch('resources').map do |res|
            res['metadata']['guid']
          end

          returned_service_guids = decoded_response.fetch('resources').map do |res|
            res['entity']['service_guid']
          end

          expect(returned_plan_guids).to match_array expected_plan_guids
          expect(returned_service_guids).to match_array expected_service_guids
        end

        it 'does not allow the unauthed user to use inline-relations-depth' do
          get '/v2/service_plans?inline-relations-depth=1'
          plans = decoded_response.fetch('resources').map { |plan| plan['entity'] }
          plans.each do |plan|
            expect(plan['service_instances']).to be_nil
          end
        end

        it 'does allow the unauthed user to filter by service guid' do
          service_plan = @services[:public].first
          service_guid = service_plan.service.guid

          get "/v2/service_plans?q=service_guid:#{service_guid}"

          plans = decoded_response.fetch('resources').map { |plan| plan['entity'] }
          expect(plans.size).to eq(1)
          expect(plans[0]['unique_id']).to eq(service_plan.unique_id)
        end
      end

      context 'when the user has an expired token' do
        it 'raises an InvalidAuthToken error' do
          set_current_user(developer, token: :invalid_token)
          get '/v2/service_plans'
          expect(last_response.status).to eq 401
        end
      end
    end

    describe 'PUT', '/v2/service_plans/:guid' do
      context 'when fields other than public are requested' do
        it 'only updates the public field' do
          service_plan = ServicePlan.make(name: 'old-name', public: true)
          payload = MultiJson.dump({ 'name' => 'new-name', 'public' => false })

          set_current_user_as_admin
          put "/v2/service_plans/#{service_plan.guid}", payload

          expect(last_response.status).to eq(201)
          service_plan.reload
          expect(service_plan.name).to eq('old-name')
          expect(service_plan.public).to eq(false)
        end
      end
    end

    describe 'DELETE', '/v2/service_plans/:guid' do
      let(:service_plan) { ServicePlan.make }

      it 'should prevent recursive deletions if there are any instances' do
        set_current_user_as_admin
        ManagedServiceInstance.make(service_plan: service_plan)
        delete "/v2/service_plans/#{service_plan.guid}?recursive=true"
        expect(last_response.status).to eq(400)

        expect(decoded_response.fetch('code')).to eq(10006)
        expect(decoded_response.fetch('description')).to eq('Please delete the service_instances associations for your service_plans.')
      end
    end
  end
end
