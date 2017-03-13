require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::SpacesController do
    let(:organization_one) { Organization.make }
    let(:space_one) { Space.make(organization: organization_one) }
    let(:user_email) { Sham.email }

    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
      it { expect(described_class).to be_queryable_by(:organization_guid) }
      it { expect(described_class).to be_queryable_by(:developer_guid) }
      it { expect(described_class).to be_queryable_by(:app_guid) }
      it { expect(described_class).to be_queryable_by(:isolation_segment_guid) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name:                         { type: 'string', required: true },
          allow_ssh:                    { type: 'bool', default: true },
          isolation_segment_guid:       { type: 'string', default: nil, required: false },
          organization_guid:            { type: 'string', required: true },
          developer_guids:              { type: '[string]' },
          manager_guids:                { type: '[string]' },
          auditor_guids:                { type: '[string]' },
          domain_guids:                 { type: '[string]' },
          service_instance_guids:       { type: '[string]' },
          security_group_guids:         { type: '[string]' },
          staging_security_group_guids: { type: '[string]' },
          space_quota_definition_guid:  { type: 'string' }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name:                         { type: 'string' },
          allow_ssh:                    { type: 'bool' },
          isolation_segment_guid:       { type: 'string', required: false },
          organization_guid:            { type: 'string' },
          developer_guids:              { type: '[string]' },
          manager_guids:                { type: '[string]' },
          auditor_guids:                { type: '[string]' },
          domain_guids:                 { type: '[string]' },
          service_instance_guids:       { type: '[string]' },
          security_group_guids:         { type: '[string]' },
          staging_security_group_guids: { type: '[string]' },
        })
      end
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        @obj_a = @space_a
        @obj_b = @space_b
      end

      describe 'Org Level Permissions' do
        describe 'OrgManager' do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples 'permission enumeration', 'OrgManager',
            name: 'space',
            path: '/v2/spaces',
            enumerate: 1
        end

        describe 'OrgUser' do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples 'permission enumeration', 'OrgUser',
            name: 'space',
            path: '/v2/spaces',
            enumerate: 0
        end

        describe 'BillingManager' do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples 'permission enumeration', 'BillingManager',
            name: 'space',
            path: '/v2/spaces',
            enumerate: 0
        end

        describe 'Auditor' do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples 'permission enumeration', 'Auditor',
            name: 'space',
            path: '/v2/spaces',
            enumerate: 0
        end
      end

      describe 'App Space Level Permissions' do
        describe 'SpaceManager' do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples 'permission enumeration', 'SpaceManager',
            name: 'space',
            path: '/v2/spaces',
            enumerate: 1
        end

        describe 'Developer' do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples 'permission enumeration', 'Developer',
            name: 'space',
            path: '/v2/spaces',
            enumerate: 1
        end

        describe 'SpaceAuditor' do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples 'permission enumeration', 'SpaceAuditor',
            name: 'space',
            path: '/v2/spaces',
            enumerate: 1
        end
      end
    end

    describe 'Associations' do
      before { set_current_user_as_admin }

      it do
        expect(described_class).to have_nested_routes(
          {
            developers:              [:get, :put, :delete],
            managers:                [:get, :put, :delete],
            auditors:                [:get, :put, :delete],
            apps:                    [:get],
            routes:                  [:get],
            domains:                 [:get, :put, :delete],
            service_instances:       [:get],
            app_events:              [:get],
            events:                  [:get],
            security_groups:         [:get, :put, :delete],
            staging_security_groups: [:get, :put, :delete],
          })
      end

      describe 'app_events associations' do
        it 'does not return app_events with inline-relations-depth=0' do
          space = Space.make
          get "/v2/spaces/#{space.guid}?inline-relations-depth=0"
          expect(entity).to have_key('app_events_url')
          expect(entity).to_not have_key('app_events')
        end

        it 'does not return app_events with inline-relations-depth=1 since app_events dataset is relatively expensive to query' do
          space = Space.make
          get "/v2/spaces/#{space.guid}?inline-relations-depth=1"
          expect(entity).to have_key('app_events_url')
          expect(entity).to_not have_key('app_events')
        end
      end

      describe 'events associations' do
        it 'does not return events with inline-relations-depth=0' do
          space = Space.make
          get "/v2/spaces/#{space.guid}?inline-relations-depth=0"
          expect(entity).to have_key('events_url')
          expect(entity).to_not have_key('events')
        end

        it 'does not return events with inline-relations-depth=1 since events dataset is relatively expensive to query' do
          space = Space.make
          get "/v2/spaces/#{space.guid}?inline-relations-depth=1"
          expect(entity).to have_key('events_url')
          expect(entity).to_not have_key('events')
        end
      end
    end

    it 'can order by name and id when listing' do
      expect(described_class.sortable_parameters).to match_array([:id, :name])
    end

    describe 'GET /v2/spaces/:guid/user_roles' do
      context 'for an space that does not exist' do
        it 'returns a 404' do
          set_current_user_as_admin
          get '/v2/spaces/foobar/user_roles'
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the user does not have permissions to read' do
        it 'returns a 403' do
          set_current_user(User.make)
          get "/v2/spaces/#{space_one.guid}/user_roles"
          expect(last_response.status).to eq(403)
        end
      end
    end

    describe 'GET /v2/spaces/:guid/service_instances' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }

      before { set_current_user(developer) }

      context 'when filtering results' do
        it 'returns only matching results' do
          user_provided_service_instance_1 = UserProvidedServiceInstance.make(space: space, name: 'provided service 1')
          UserProvidedServiceInstance.make(space: space, name: 'provided service 2')
          managed_service_instance_1 = ManagedServiceInstance.make(space: space, name: 'managed service 1')
          ManagedServiceInstance.make(space: space, name: 'managed service 2')

          get "v2/spaces/#{space.guid}/service_instances", { 'q' => 'name:provided service 1;', 'return_user_provided_service_instances' => true }
          guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
          expect(guids).to eq([user_provided_service_instance_1.guid])

          get "v2/spaces/#{space.guid}/service_instances", { 'q' => 'name:managed service 1;', 'return_user_provided_service_instances' => true }
          guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
          expect(guids).to eq([managed_service_instance_1.guid])
        end
      end

      context 'when there are provided service instances' do
        let!(:user_provided_service_instance) { UserProvidedServiceInstance.make(space: space) }
        let!(:managed_service_instance) { ManagedServiceInstance.make(space: space) }

        describe 'when return_user_provided_service_instances is true' do
          it 'returns ManagedServiceInstances and UserProvidedServiceInstances' do
            get "v2/spaces/#{space.guid}/service_instances", { return_user_provided_service_instances: true }

            guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
            expect(guids).to include(user_provided_service_instance.guid, managed_service_instance.guid)
          end

          it 'includes service_plan_url for managed service instances' do
            get "/v2/spaces/#{space.guid}/service_instances", { return_user_provided_service_instances: true }
            service_instances_response = decoded_response.fetch('resources')
            managed_service_instance_response = service_instances_response.detect { |si|
              si.fetch('metadata').fetch('guid') == managed_service_instance.guid
            }
            expect(managed_service_instance_response.fetch('entity').fetch('service_plan_url')).to be
            expect(managed_service_instance_response.fetch('entity').fetch('space_url')).to be
            expect(managed_service_instance_response.fetch('entity').fetch('service_bindings_url')).to be
          end

          it 'includes the correct service binding url' do
            get "/v2/spaces/#{space.guid}/service_instances", { return_user_provided_service_instances: true }
            service_instances_response = decoded_response.fetch('resources')
            user_provided_service_instance_response = service_instances_response.detect { |si|
              si.fetch('metadata').fetch('guid') == user_provided_service_instance.guid
            }
            expect(user_provided_service_instance_response.fetch('entity').fetch('service_bindings_url')).to include('user_provided_service_instance')
          end

          it 'presents pagination link urls with the return_user_provided_service_instances param' do
            get "v2/spaces/#{space.guid}/service_instances", { return_user_provided_service_instances: true, 'results-per-page': 1 }

            next_url = decoded_response.fetch('next_url')
            expect(next_url).to include('return_user_provided_service_instances=true')
          end
        end

        describe 'when return_user_provided_service_instances flag is not present' do
          it 'returns only the managed service instances' do
            get "/v2/spaces/#{space.guid}/service_instances"
            guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
            expect(guids).to match_array([managed_service_instance.guid])
          end

          it 'includes service_plan_url for managed service instances' do
            get "/v2/spaces/#{space.guid}/service_instances"
            service_instances_response = decoded_response.fetch('resources')
            managed_service_instance_response = service_instances_response.detect { |si|
              si.fetch('metadata').fetch('guid') == managed_service_instance.guid
            }
            expect(managed_service_instance_response.fetch('entity').fetch('service_plan_url')).to be
            expect(managed_service_instance_response.fetch('entity').fetch('space_url')).to be
            expect(managed_service_instance_response.fetch('entity').fetch('service_bindings_url')).to be
          end
        end
      end

      describe 'Permissions' do
        include_context 'permissions'
        shared_examples 'disallow enumerating service instances' do |perm_name|
          describe 'disallowing enumerating service instances' do
            it "disallows a user that only has #{perm_name} permission on the space" do
              set_current_user(member_a)

              get "/v2/spaces/#{@space_a.guid}/service_instances"

              expect(last_response).to have_status_code(403)
            end
          end
        end

        shared_examples 'enumerating service instances' do |perm_name, opts|
          expected = opts.fetch(:expected)
          let(:path) { "/v2/spaces/#{@space_a.guid}/service_instances" }
          let!(:managed_service_instance) do
            ManagedServiceInstance.make(
              space: @space_a,
            )
          end

          it "should return service instances to a user that has #{perm_name} permissions" do
            set_current_user(member_a)

            get path

            expect(last_response).to be_ok
            expect(decoded_response['total_results']).to eq(expected)
            guids = decoded_response['resources'].map { |o| o['metadata']['guid'] }
            expect(guids).to include(managed_service_instance.guid) if expected > 0
          end

          it "should not return a service instance to a user with the #{perm_name} permission on a different space" do
            set_current_user(member_b)
            get path
            expect(last_response).to have_status_code(403)
          end
        end

        shared_examples 'disallow enumerating services' do |perm_name|
          describe 'disallowing enumerating services' do
            it "disallows a user that only has #{perm_name} permission on the space" do
              set_current_user(member_a)
              get "/v2/spaces/#{@space_a.guid}/services"
              expect(last_response).to be_forbidden
            end
          end
        end

        shared_examples 'enumerating services' do |perm_name, opts|
          let(:path) { "/v2/spaces/#{@space_a.guid}/services" }

          it "should return services to a user that has #{perm_name} permissions" do
            set_current_user(member_a)
            get path
            expect(last_response).to be_ok
          end

          it "should not return services to a user with the #{perm_name} permission on a different space" do
            set_current_user(member_b)
            get path
            expect(last_response).to be_forbidden
          end
        end

        describe 'Org Level' do
          describe 'OrgManager' do
            it_behaves_like(
              'enumerating service instances', 'OrgManager',
              expected: 1,
            ) do
              let(:member_a) { @org_a_manager }
              let(:member_b) { @org_b_manager }
            end

            it_behaves_like(
              'enumerating services', 'OrgManager',
            ) do
              let(:member_a) { @org_a_manager }
              let(:member_b) { @org_b_manager }
            end
          end

          describe 'OrgUser' do
            it_behaves_like(
              'disallow enumerating service instances', 'OrgUser',
            ) do
              let(:member_a) { @org_a_member }
            end

            it_behaves_like(
              'disallow enumerating services', 'OrgUser',
            ) do
              let(:member_a) { @org_a_member }
            end
          end

          describe 'BillingManager' do
            it_behaves_like(
              'disallow enumerating service instances', 'BillingManager',
            ) do
              let(:member_a) { @org_a_billing_manager }
            end

            it_behaves_like(
              'disallow enumerating services', 'BillingManager',
            ) do
              let(:member_a) { @org_a_billing_manager }
            end
          end

          describe 'Auditor' do
            it_behaves_like(
              'disallow enumerating service instances', 'Auditor',
            ) do
              let(:member_a) { @org_a_auditor }
            end

            it_behaves_like(
              'disallow enumerating services', 'Auditor',
            ) do
              let(:member_a) { @org_a_auditor }
            end
          end
        end

        describe 'App Space Level Permissions' do
          describe 'SpaceManager' do
            it_behaves_like(
              'enumerating service instances', 'SpaceManager',
              expected: 1,
            ) do
              let(:member_a) { @space_a_manager }
              let(:member_b) { @space_b_manager }
            end

            it_behaves_like(
              'enumerating services', 'SpaceManager',
            ) do
              let(:member_a) { @space_a_manager }
              let(:member_b) { @space_b_manager }
            end
          end

          describe 'Developer' do
            it_behaves_like(
              'enumerating service instances', 'Developer',
              expected: 1,
            ) do
              let(:member_a) { @space_a_developer }
              let(:member_b) { @space_b_developer }
            end

            it_behaves_like(
              'enumerating services', 'Developer',
            ) do
              let(:member_a) { @space_a_developer }
              let(:member_b) { @space_b_developer }
            end
          end

          describe 'SpaceAuditor' do
            it_behaves_like(
              'enumerating service instances', 'SpaceAuditor',
              expected: 1,
            ) do
              let(:member_a) { @space_a_auditor }
              let(:member_b) { @space_b_auditor }
            end

            it_behaves_like(
              'enumerating services', 'SpaceAuditor',
            ) do
              let(:member_a) { @space_a_auditor }
              let(:member_b) { @space_b_auditor }
            end
          end
        end
      end
    end

    describe 'GET', '/v2/spaces/:guid/services' do
      let(:organization_two) { Organization.make }
      let(:space_one) { Space.make(organization: organization_one) }
      let(:space_two) { Space.make(organization: organization_two) }
      let(:user) { make_developer_for_space(space_one) }

      before do
        user.add_organization(organization_two)
        space_two.add_developer(user)
        set_current_user(user)
      end

      def decoded_guids
        decoded_response['resources'].map { |r| r['metadata']['guid'] }
      end

      context 'when there is a private service broker in a space' do
        before(:each) do
          @broker       = ServiceBroker.make(space: space_one)
          @service      = Service.make(service_broker: @broker, active: true)
          @service_plan = ServicePlan.make(service: @service, public: false)
        end

        let(:developer) { user }
        let(:outside_developer) { make_developer_for_space(space_two) }

        let(:auditor) { make_auditor_for_space(space_one) }
        let(:outside_auditor) { make_auditor_for_space(space_two) }

        let(:manager) { make_manager_for_space(space_one) }
        let(:outside_manager) { make_manager_for_space(space_two) }

        it 'should be visible to SpaceDevelopers' do
          set_current_user(developer)
          get "v2/spaces/#{space_one.guid}/services"
          expect(decoded_guids).to include(@service.guid)
        end

        it 'should not be visible to outside SpaceDevelopers, even in their own space' do
          set_current_user(outside_developer)
          get "v2/spaces/#{space_two.guid}/services"
          expect(decoded_guids).not_to include(@service.guid)
        end

        it 'should be visible to SpaceManagers ' do
          set_current_user(manager)
          get "v2/spaces/#{space_one.guid}/services"
          expect(decoded_guids).to include(@service.guid)
        end

        it 'should be visible to SpaceManagers' do
          set_current_user(outside_manager)
          get "v2/spaces/#{space_one.guid}/services"
          expect(last_response).not_to be_ok
        end

        it 'should be visible to SpaceAuditor' do
          set_current_user(auditor)
          get "v2/spaces/#{space_one.guid}/services"
          expect(decoded_guids).to include(@service.guid)
        end

        it 'should be visible to SpaceManagers' do
          set_current_user(outside_auditor)
          get "v2/spaces/#{space_one.guid}/services"
          expect(last_response).not_to be_ok
        end
      end

      context 'with an offering that has private plans' do
        before(:each) do
          @service = Service.make(active: true)
          @service_plan = ServicePlan.make(service: @service, public: false)
          ServicePlanVisibility.make(service_plan: @service.service_plans.first, organization: organization_one)
        end

        it "should remove the offering when the org does not have access to any of the service's plans" do
          get "/v2/spaces/#{space_two.guid}/services"
          expect(last_response).to be_ok
          expect(decoded_guids).not_to include(@service.guid)
        end

        it "should return the offering when the org has access to one of the service's plans" do
          get "/v2/spaces/#{space_one.guid}/services"
          expect(last_response).to be_ok
          expect(decoded_guids).to include(@service.guid)
        end

        it 'should include plans that are visible to the org' do
          get "/v2/spaces/#{space_one.guid}/services?inline-relations-depth=1"

          expect(last_response).to be_ok
          service = decoded_response.fetch('resources').fetch(0)
          service_plans = service.fetch('entity').fetch('service_plans')
          expect(service_plans.length).to eq(1)
          expect(service_plans.first.fetch('metadata').fetch('guid')).to eq(@service_plan.guid)
          expect(service_plans.first.fetch('metadata').fetch('url')).to eq("/v2/service_plans/#{@service_plan.guid}")
        end

        it 'should exclude plans that are not visible to the org' do
          public_service_plan = ServicePlan.make(service: @service, public: true)

          get "/v2/spaces/#{space_two.guid}/services?inline-relations-depth=1"

          expect(last_response).to be_ok
          service = decoded_response.fetch('resources').fetch(0)
          service_plans = service.fetch('entity').fetch('service_plans')
          expect(service_plans.length).to eq(1)
          expect(service_plans.first.fetch('metadata').fetch('guid')).to eq(public_service_plan.guid)
        end
      end

      describe 'get /v2/spaces/:guid/services?q=active:<t|f>' do
        before(:each) do
          @active = Array.new(3) { Service.make(active: true).tap { |svc| ServicePlan.make(service: svc) } }
          @inactive = Array.new(2) { Service.make(active: false).tap { |svc| ServicePlan.make(service: svc) } }
        end

        it 'can remove inactive services' do
          get "/v2/spaces/#{space_one.guid}/services?q=active:t"
          expect(last_response).to be_ok
          expect(decoded_guids).to match_array(@active.map(&:guid))
        end

        it 'can only get inactive services' do
          get "/v2/spaces/#{space_one.guid}/services?q=active:f"
          expect(last_response).to be_ok
          expect(decoded_guids).to match_array(@inactive.map(&:guid))
        end
      end
    end

    describe 'audit events' do
      let(:user_email) { Sham.email }
      let(:space) { Space.make }

      before { set_current_user_as_admin(email: user_email) }

      it 'logs audit.space.create when creating a space' do
        request_body = { organization_guid: space.organization.guid, name: 'space_name' }.to_json
        post '/v2/spaces', request_body

        expect(last_response).to have_status_code(201)

        new_space_guid = decoded_response['metadata']['guid']
        event = Event.find(type: 'audit.space.create', actee: new_space_guid)
        expect(event).not_to be_nil

        expect(event.actor_name).to eq(SecurityContext.current_user_email)
        expect(event.metadata['request']).to include('organization_guid' => space.organization.guid, 'name' => 'space_name')
      end

      it 'logs audit.space.update when updating a space' do
        request_body = { name: 'new_space_name' }.to_json
        put "/v2/spaces/#{space.guid}", request_body

        expect(last_response).to have_status_code(201)

        event = Event.find(type: 'audit.space.update', actee: space.guid)
        expect(event).not_to be_nil
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
        expect(event.metadata['request']).to eq('name' => 'new_space_name')
      end

      it 'logs audit.space.delete-request when deleting a space' do
        delete "/v2/spaces/#{space.guid}?recursive=true"

        expect(last_response).to have_status_code(204)

        event = Event.find(type: 'audit.space.delete-request', actee: space.guid)
        expect(event).not_to be_nil
        expect(event.metadata['request']).to eq('recursive' => true)
        expect(event.space_guid).to eq(space.guid)
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
        expect(event.organization_guid).to eq(space.organization.guid)
      end
    end

    describe 'DELETE /v2/spaces/:guid' do
      context 'when recursive is false' do
        let(:space) { Space.make }

        before { set_current_user_as_admin }

        it 'successfully deletes spaces with no associations' do
          delete "/v2/spaces/#{space.guid}"

          expect(last_response).to have_status_code(204)
          expect(Space.find(guid: space.guid)).to be_nil
        end

        it 'fails to delete spaces with apps associated to it' do
          AppModel.make(space: space)
          delete "/v2/spaces/#{space.guid}"

          expect(last_response).to have_status_code(400)
          expect(Space.find(guid: space.guid)).not_to be_nil
        end

        it 'fails to delete spaces with service_instances associated to it' do
          ServiceInstance.make(space: space)
          delete "/v2/spaces/#{space.guid}"

          expect(last_response).to have_status_code(400)
          expect(Space.find(guid: space.guid)).not_to be_nil
        end

        context 'when a service broker exists in the space' do
          let!(:broker) { VCAP::CloudController::ServiceBroker.make(space_guid: space.guid) }

          it 'fails to delete spaces with service brokers (private brokers) associated to it' do
            delete "/v2/spaces/#{space.guid}"

            expect(last_response).to have_status_code(400)
            expect(Space.find(guid: space.guid)).not_to be_nil
          end

          context 'when user is an Org Manager' do
            let(:user) { make_manager_for_org(space.organization) }

            it 'fails to delete spaces with associated private service brokers' do
              set_current_user(user)
              delete "/v2/spaces/#{space.guid}"

              expect(last_response).to have_status_code(400)
              expect(Space.find(guid: space.guid)).not_to be_nil
            end
          end
        end
      end

      context 'when recursive is true' do
        let!(:org) { Organization.make }
        let!(:space) { Space.make(organization: org) }
        let!(:space_guid) { space.guid }
        let!(:app_guid) { AppModel.make(space_guid: space_guid).guid }
        let!(:route_guid) { Route.make(space_guid: space_guid).guid }
        let!(:service_instance) { ManagedServiceInstance.make(space_guid: space_guid) }
        let!(:service_instance_guid) { service_instance.guid }
        let!(:user) { make_manager_for_org(org) }

        before do
          stub_deprovision(service_instance, accepts_incomplete: true)
          set_current_user(user, admin: true)
        end

        it 'successfully deletes spaces with v3 app associations' do
          delete "/v2/spaces/#{space_guid}?recursive=true"

          expect(last_response).to have_status_code(204)
          expect(Space.find(guid: space_guid)).to be_nil
          expect(AppModel.find(guid: app_guid)).to be_nil
          expect(Route.find(guid: route_guid)).to be_nil
        end

        it 'successfully deletes the space in a background job when async=true' do
          delete "/v2/spaces/#{space_guid}?recursive=true&async=true"

          expect(last_response).to have_status_code(202)
          expect(Space.find(guid: space_guid)).not_to be_nil
          expect(AppModel.find(guid: app_guid)).not_to be_nil
          expect(ServiceInstance.find(guid: service_instance_guid)).not_to be_nil
          expect(Route.find(guid: route_guid)).not_to be_nil

          space_delete_jobs = Delayed::Job.where("handler like '%SpaceDelete%'")
          expect(space_delete_jobs.count).to eq 1
          job = space_delete_jobs.first

          Delayed::Worker.new.work_off

          # a successfully completed job is removed from the table
          expect(Delayed::Job.find(id: job.id)).to be_nil

          expect(Space.find(guid: space_guid)).to be_nil
          expect(AppModel.find(guid: app_guid)).to be_nil
          expect(ServiceInstance.find(guid: service_instance_guid)).to be_nil
          expect(Route.find(guid: route_guid)).to be_nil
        end

        it 'records an audit event for the deletion of any nested resources' do
          set_current_user(user, email: 'user@email.com')
          delete "/v2/spaces/#{space_guid}?recursive=true"

          event = Event.find(type: 'audit.app.delete-request', actee: app_guid)
          expect(event).not_to be_nil
          expect(event.actor).to eq user.guid
          expect(event.actor_name).to eq 'user@email.com'
        end

        context 'when the async job times out' do
          before do
            fake_config = {
              jobs: {
                global: {
                  timeout_in_seconds: 0.1
                }
              }
            }
            allow(VCAP::CloudController::Config).to receive(:config).and_return(fake_config)
            stub_deprovision(service_instance, accepts_incomplete: true) do
              sleep 0.11
              { status: 200, body: {}.to_json }
            end
          end

          it 'fails the job with a SpaceDeleteTimeout error' do
            delete "/v2/spaces/#{space_guid}?recursive=true&async=true"
            expect(last_response).to have_status_code(202)
            job_guid = decoded_response['metadata']['guid']

            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            get "/v2/jobs/#{job_guid}"
            expect(decoded_response['entity']['status']).to eq 'failed'
            expect(decoded_response['entity']['error_details']['error_code']).to eq 'CF-SpaceDeleteTimeout'
          end
        end

        describe 'deleting service instances' do
          let(:app_model) { AppModel.make(space: space) }
          let!(:service_instance_1) { ManagedServiceInstance.make(space_guid: space_guid) }
          let!(:service_instance_2) { ManagedServiceInstance.make(space_guid: space_guid) }
          let!(:service_instance_3) { ManagedServiceInstance.make(space_guid: space_guid) }
          let!(:user_provided_service_instance) { UserProvidedServiceInstance.make(space_guid: space_guid) }

          before do
            stub_deprovision(service_instance_1, accepts_incomplete: true)
            stub_deprovision(service_instance_2, accepts_incomplete: true)
            stub_deprovision(service_instance_3, accepts_incomplete: true)
          end

          it 'successfully deletes spaces with managed service instances' do
            delete "/v2/spaces/#{space_guid}?recursive=true"

            expect(last_response).to have_status_code(204)
            expect(service_instance_1.exists?).to be_falsey
            expect(service_instance_2.exists?).to be_falsey
            expect(service_instance_3.exists?).to be_falsey
          end

          it 'successfully deletes spaces with user_provided service instances' do
            delete "/v2/spaces/#{space_guid}?recursive=true"

            expect(last_response).to have_status_code(204)
            expect(user_provided_service_instance.exists?).to be_falsey
          end

          context 'when the second of three bindings fails to delete' do
            let!(:binding_1) { ServiceBinding.make(service_instance: service_instance_1, app: app_model) }
            let!(:binding_2) { ServiceBinding.make(service_instance: service_instance_2, app: app_model) }
            let!(:binding_3) { ServiceBinding.make(service_instance: service_instance_3, app: app_model) }

            before do
              stub_unbind(binding_1)
              stub_unbind(binding_2, status: 500)
              stub_unbind(binding_3)
            end

            it 'deletes the first and third of the instances and their bindings' do
              delete "/v2/spaces/#{space_guid}?recursive=true"

              expect(last_response).to have_status_code 502
              expect(decoded_response['error_code']).to eq 'CF-SpaceDeletionFailed'

              expect { service_instance_1.refresh }.to raise_error Sequel::Error, 'Record not found'
              expect { service_instance_2.refresh }.not_to raise_error
              expect { service_instance_3.refresh }.to raise_error Sequel::Error, 'Record not found'

              expect { binding_1.refresh }.to raise_error Sequel::Error, 'Record not found'
              expect { binding_2.refresh }.not_to raise_error
              expect { binding_3.refresh }.to raise_error Sequel::Error, 'Record not found'
            end

            it 'does not delete any of the v2 apps' do
              expect {
                delete "/v2/spaces/#{space_guid}?recursive=true"
              }.to_not change { App.count }
            end

            it 'does not delete any of the v3 apps' do
              expect {
                delete "/v2/spaces/#{space_guid}?recursive=true"
              }.not_to change { AppModel.count }
            end
          end

          context 'when user is an Org Manager' do
            let!(:space)  { Space.make }
            let(:user)    { make_manager_for_org(space.organization) }
            let!(:broker) { VCAP::CloudController::ServiceBroker.make(space_guid: space.guid) }

            it 'successfully deletes spaces with associated private service brokers' do
              set_current_user(user)
              delete "/v2/spaces/#{space.guid}?recursive=true"

              expect(last_response).to have_status_code(204)
              expect(Space.find(guid: space.guid)).to be_nil
              expect(ServiceBroker.find(guid: broker.guid)).to be_nil
            end
          end

          context 'when the second of three service instances fails to delete' do
            before do
              stub_deprovision(service_instance_2, status: 500, accepts_incomplete: true)

              instance_url = remove_basic_auth(deprovision_url(service_instance_2))

              @expected_description = "Deletion of space #{space.name} failed because one or more resources within could not be deleted.

\tService instance #{service_instance_2.name}: The service broker returned an invalid response for the request to #{instance_url}. Status Code: 500 Internal Server Error, Body: {}"
            end

            context 'synchronous' do
              it 'deletes the first and third instances and returns an error' do
                delete "/v2/spaces/#{space_guid}?recursive=true"

                expect(last_response).to have_status_code 502
                expect(decoded_response['error_code']).to eq 'CF-SpaceDeletionFailed'
                expect(decoded_response['description']).to eq @expected_description

                expect { service_instance_1.refresh }.to raise_error Sequel::Error, 'Record not found'
                expect { service_instance_2.refresh }.not_to raise_error
                expect { service_instance_3.refresh }.to raise_error Sequel::Error, 'Record not found'
              end
            end

            context 'when async=true' do
              it 'deletes the first and third instances and returns an error' do
                delete "/v2/spaces/#{space_guid}?recursive=true&async=true"
                expect(last_response).to have_status_code 202
                job_url = MultiJson.load(last_response.body)['metadata']['url']

                Delayed::Worker.new.work_off

                space_delete_jobs = Delayed::Job.where("handler like '%SpaceDelete%'")
                expect(space_delete_jobs.count).to eq 1
                expect(space_delete_jobs.first.last_error).not_to be_nil

                get job_url
                expect(last_response).to have_status_code 200

                expect(MultiJson.load(last_response.body)['entity']['error_details']).to eq({
                  'error_code' => 'CF-SpaceDeletionFailed',
                  'description' => @expected_description,
                  'code' => 290008
                })

                expect { service_instance_1.refresh }.to raise_error Sequel::Error, 'Record not found'
                expect { service_instance_2.refresh }.not_to raise_error
                expect { service_instance_3.refresh }.to raise_error Sequel::Error, 'Record not found'
              end
            end
          end

          context 'when an instance has an operation in progress' do
            let(:last_operation) { ServiceInstanceOperation.make(state: 'in progress') }

            before do
              service_instance_1.service_instance_operation = last_operation
            end

            it 'returns an error to the user' do
              delete "/v2/spaces/#{space_guid}?recursive=true"
              expect(last_response).to have_status_code 502
              expect(decoded_response['error_code']).to eq 'CF-SpaceDeletionFailed'
              expect(last_response.body).to match /An operation for service instance #{service_instance_1.name} is in progress./
            end

            it 'does not delete that instance' do
              delete "/v2/spaces/#{space_guid}?recursive=true"
              expect(space.exists?).to be_truthy
              expect(service_instance_1.exists?).to be_truthy
            end

            it 'deletes the other service instances' do
              delete "/v2/spaces/#{space_guid}?recursive=true"
              expect(service_instance_2.exists?).to be_falsey
              expect(service_instance_3.exists?).to be_falsey
              expect(user_provided_service_instance.exists?).to be_falsey
            end

            context 'when async=true' do
              it 'returns an error to the user' do
                delete "/v2/spaces/#{space_guid}?recursive=true&async=true"
                expect(last_response).to have_status_code 202

                Delayed::Worker.new.work_off

                space_delete_jobs = Delayed::Job.where("handler like '%SpaceDelete%'")
                expect(space_delete_jobs.count).to eq 1
                expect(space_delete_jobs.first.last_error).not_to be_nil

                job_url = decoded_response['metadata']['url']

                get job_url
                expect(last_response).to have_status_code 200
                expect(decoded_response['entity']['error_details']['error_code']).to eq 'CF-SpaceDeletionFailed'
                expect(decoded_response['entity']['error_details']['description']).to match /An operation for service instance #{service_instance_1.name} is in progress./
              end

              it 'does not delete that instance' do
                delete "/v2/spaces/#{space_guid}?recursive=true&async=true"

                Delayed::Worker.new.work_off

                space_delete_jobs = Delayed::Job.where("handler like '%SpaceDelete%'")
                expect(space_delete_jobs.count).to eq 1
                expect(space_delete_jobs.first.last_error).not_to be_nil

                expect(space.exists?).to be_truthy
                expect(service_instance_1.exists?).to be_truthy
              end

              it 'deletes the other service instances' do
                delete "/v2/spaces/#{space_guid}?recursive=true&async=true"

                Delayed::Worker.new.work_off

                space_delete_jobs = Delayed::Job.where("handler like '%SpaceDelete%'")
                expect(space_delete_jobs.count).to eq 1
                expect(space_delete_jobs.first.last_error).not_to be_nil

                expect(service_instance_2.exists?).to be_falsey
                expect(service_instance_3.exists?).to be_falsey
                expect(user_provided_service_instance.exists?).to be_falsey
              end
            end
          end
        end
      end
    end

    describe 'GET /v2/spaces/:guid/users' do
      let(:mgr) { User.make }
      let(:user) { User.make }
      let(:org) { Organization.make(manager_guids: [mgr.guid], user_guids: [mgr.guid, user.guid]) }
      let(:space) { Space.make(organization: org, manager_guids: [mgr.guid], developer_guids: [user.guid]) }
      before do
        allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).and_return({})
      end

      it 'allows space managers' do
        set_current_user(mgr)
        get "/v2/spaces/#{space.guid}/developers"
        expect(last_response).to have_status_code(200)
      end

      it 'allows space developers' do
        set_current_user(user)
        get "/v2/spaces/#{space.guid}/developers"
        expect(last_response).to have_status_code(200)
      end
    end

    describe 'DELETE /v2/spaces/:guid/developers/:user_guid' do
      let(:mgr) { User.make }
      let(:developer) { User.make }
      let(:org) { Organization.make(manager_guids: [mgr.guid], user_guids: org_user_guids) }
      let(:space) { Space.make(
        organization: org,
        manager_guids: [mgr.guid],
        developer_guids: space_dev_guids,
        auditor_guids: space_auditor_guids)
      }
      let(:space_dev_guids) { [developer.guid] }
      let(:org_user_guids) { [mgr.guid, developer.guid] }
      let(:space_auditor_guids) { [] }

      before do
        allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).with([developer.guid]).and_return({ developer.guid => developer.username })
      end

      context 'as admin who is not a developer or manager' do
        before do
          set_current_user_as_admin(user: User.make)
        end

        it 'successfully removes the developer' do
          delete "/v2/spaces/#{space.guid}/developers/#{developer.guid}"
          expect(last_response).to have_status_code(204)
        end
      end

      context 'as manager who is not a developer' do
        before do
          set_current_user(mgr)
        end

        it 'successfully removes the developer' do
          delete "/v2/spaces/#{space.guid}/developers/#{developer.guid}"
          expect(last_response).to have_status_code(204)
        end
      end

      context 'as a developer' do
        before do
          set_current_user(developer)
        end

        context 'when removing themself' do
          it 'successfully removes the developer' do
            delete "/v2/spaces/#{space.guid}/developers/#{developer.guid}"
            expect(last_response).to have_status_code(204)
          end
        end

        context 'when removing another developer' do
          let(:dev) { User.make }
          let(:space_dev_guids) { [dev.guid, developer.guid] }
          let(:org_user_guids) { [mgr.guid, developer.guid, dev.guid] }

          before do
            allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).with([dev.guid]).and_return({ dev.guid => dev.username })
          end

          it 'fails with a 403' do
            delete "/v2/spaces/#{space.guid}/developers/#{dev.guid}"
            expect(last_response).to have_status_code(403)
            expect(decoded_response['code']).to eq(10003)
          end
        end
      end

      context 'as an auditor who is not a developer' do
        let(:auditor) { User.make }
        let(:space_auditor_guids) { [auditor.guid] }
        let(:org_user_guids) { [mgr.guid, developer.guid, auditor.guid] }

        before do
          set_current_user(auditor)
        end

        it 'fails with a 403' do
          delete "/v2/spaces/#{space.guid}/developers/#{developer.guid}"
          expect(last_response).to have_status_code(403)
          expect(decoded_response['code']).to eq(10003)
        end
      end
    end

    describe 'DELETE /v2/spaces/:guid/managers/:user_guid' do
      let(:manager) { User.make }
      let(:developer) { User.make }
      let(:org) { Organization.make(manager_guids: [manager.guid], user_guids: org_user_guids) }
      let(:space) { Space.make(
        organization: org,
        manager_guids: space_manager_guids,
        developer_guids: space_dev_guids,
        auditor_guids: space_auditor_guids)
      }
      let(:space_dev_guids) { [developer.guid] }
      let(:org_user_guids) { [manager.guid, developer.guid] }
      let(:space_manager_guids) { [manager.guid] }
      let(:space_auditor_guids) { [] }

      before do
        allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).with([manager.guid]).and_return({ manager.guid => manager.username })
      end

      context 'as admin who is not a developer or manager' do
        before do
          set_current_user_as_admin(user: User.make)
        end

        it 'successfully removes the manager' do
          delete "/v2/spaces/#{space.guid}/managers/#{manager.guid}"
          expect(last_response).to have_status_code(204)
        end
      end

      context 'as developer' do
        before do
          set_current_user(developer)
        end

        it 'fails with a 403' do
          delete "/v2/spaces/#{space.guid}/managers/#{manager.guid}"
          expect(last_response).to have_status_code(403)
          expect(decoded_response['code']).to eq(10003)
        end
      end

      context 'as a manager' do
        before do
          set_current_user(manager)
        end

        context 'when removing themself' do
          it 'successfully removes the manager' do
            delete "/v2/spaces/#{space.guid}/managers/#{manager.guid}"
            expect(last_response).to have_status_code(204)
          end
        end

        context 'when removing another manager' do
          let(:mgr) { User.make }
          let(:space_manager_guids) { [mgr.guid, manager.guid] }
          let(:org_user_guids) { [manager.guid, mgr.guid, developer.guid] }

          before do
            allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).with([mgr.guid]).and_return({ mgr.guid => mgr.username })
          end

          it 'successfully removes the manager' do
            delete "/v2/spaces/#{space.guid}/managers/#{mgr.guid}"
            expect(last_response).to have_status_code(204)
          end
        end
      end

      context 'as an auditor who is not a manager' do
        let(:auditor) { User.make }
        let(:space_auditor_guids) { [auditor.guid] }
        let(:org_user_guids) { [manager.guid, developer.guid, auditor.guid] }

        before do
          set_current_user(auditor)
        end

        it 'fails with a 403' do
          delete "/v2/spaces/#{space.guid}/managers/#{manager.guid}"
          expect(last_response).to have_status_code(403)
          expect(decoded_response['code']).to eq(10003)
        end
      end
    end

    describe 'DELETE /v2/spaces/:guid/auditors/:user_guid' do
      let(:manager) { User.make }
      let(:auditor) { User.make }
      let(:org) { Organization.make(manager_guids: [manager.guid], user_guids: org_user_guids) }
      let(:space) { Space.make(
        organization: org,
        manager_guids: space_manager_guids,
        developer_guids: space_dev_guids,
        auditor_guids: space_auditor_guids)
      }
      let(:space_dev_guids) { [] }
      let(:org_user_guids) { [manager.guid, auditor.guid] }
      let(:space_manager_guids) { [manager.guid] }
      let(:space_auditor_guids) { [auditor.guid] }

      before do
        allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).with([auditor.guid]).and_return({ auditor.guid => auditor.username })
      end

      context 'as admin who is not a manager' do
        before do
          set_current_user_as_admin(user: User.make)
        end

        it 'successfully removes the auditor' do
          delete "/v2/spaces/#{space.guid}/auditors/#{auditor.guid}"
          expect(last_response).to have_status_code(204)
        end
      end

      context 'as developer' do
        let(:developer) { User.make }
        let(:space_dev_guids) { [developer.guid] }
        let(:org_user_guids) { [manager.guid, auditor.guid, developer.guid] }

        before do
          set_current_user(developer)
        end

        it 'fails with a 403' do
          delete "/v2/spaces/#{space.guid}/auditors/#{auditor.guid}"
          expect(last_response).to have_status_code(403)
          expect(decoded_response['code']).to eq(10003)
        end
      end

      context 'as a manager' do
        before do
          set_current_user(manager)
        end

        it 'successfully removes the auditor' do
          delete "/v2/spaces/#{space.guid}/auditors/#{auditor.guid}"
          expect(last_response).to have_status_code(204)
        end
      end

      context 'as an auditor who is not a manager' do
        before do
          set_current_user(auditor)
        end

        context 'when removing themself' do
          it 'successfully removes the auditor' do
            delete "/v2/spaces/#{space.guid}/auditors/#{auditor.guid}"
            expect(last_response).to have_status_code(204)
          end
        end

        context 'when removing another auditor' do
          let(:auditor2) { User.make }
          let(:space_auditor_guids) { [auditor.guid, auditor2.guid] }
          let(:org_user_guids) { [manager.guid, auditor.guid, auditor2.guid] }

          before do
            allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).with([auditor2.guid]).and_return({ auditor2.guid => auditor2.username })
          end

          it 'fails with a 403' do
            delete "/v2/spaces/#{space.guid}/auditors/#{auditor2.guid}"
            expect(last_response).to have_status_code(403)
            expect(decoded_response['code']).to eq(10003)
          end
        end
      end
    end

    describe 'POST /v2/spaces' do
      let(:org) { Organization.make }
      let(:name) { 'MySpace' }

      context 'setting roles at space creation time' do
        let(:other_user) { User.make }

        before do
          set_current_user_as_admin
          org.add_user(other_user)
          org.save
          org.reload
        end

        context 'assigning a space manager' do
          it 'records an event of type audit.user.space_manager_add' do
            event = Event.find(type: 'audit.user.space_manager_add', actee: other_user.guid)
            expect(event).to be_nil

            request_body = { name: name, organization_guid: org.guid, manager_guids: [other_user.guid] }.to_json
            post '/v2/spaces', request_body

            expect(last_response).to have_status_code(201)

            event = Event.find(type: 'audit.user.space_manager_add', actee: other_user.guid)
            expect(event).not_to be_nil
          end
        end

        context 'assigning a space auditor' do
          it 'records an event of type audit.user.space_auditor_add' do
            event = Event.find(type: 'audit.user.space_auditor_add', actee: other_user.guid)
            expect(event).to be_nil

            request_body = { name: name, organization_guid: org.guid, auditor_guids: [other_user.guid] }.to_json
            post '/v2/spaces', request_body

            expect(last_response).to have_status_code(201)

            event = Event.find(type: 'audit.user.space_auditor_add', actee: other_user.guid)
            expect(event).not_to be_nil
          end
        end

        context 'assigning a space developer' do
          it 'records an event of type audit.user.space_developer_add' do
            event = Event.find(type: 'audit.user.space_developer_add', actee: other_user.guid)
            expect(event).to be_nil

            request_body = { name: name, organization_guid: org.guid, developer_guids: [other_user.guid] }.to_json
            post '/v2/spaces', request_body

            expect(last_response).to have_status_code(201)

            event = Event.find(type: 'audit.user.space_developer_add', actee: other_user.guid)
            expect(event).not_to be_nil
          end
        end
      end
    end

    describe 'PUT /v2/spaces/:guid' do
      let(:user) { set_current_user(User.make) }
      let(:isolation_segment_model) { IsolationSegmentModel.make }
      let(:organization) { Organization.make }
      let(:space) { Space.make(organization: organization) }
      let(:assigner) { IsolationSegmentAssign.new }

      context 'associating an isolation_segment' do
        before do
          assigner.assign(isolation_segment_model, [organization])
        end

        context 'when assigning the isolation segment' do
          context 'as an admin who is not a manager' do
            before do
              set_current_user_as_admin
            end

            it 'returns a 200' do
              put "/v2/spaces/#{space.guid}", MultiJson.dump({ isolation_segment_guid: isolation_segment_model.guid })

              expect(last_response.status).to eq 201
            end
          end

          context 'as an org manager' do
            before do
              space.organization.add_manager(user)
            end

            it 'returns a 201' do
              put "/v2/spaces/#{space.guid}", MultiJson.dump({ isolation_segment_guid: isolation_segment_model.guid })

              expect(last_response.status).to eq 201
              space.reload
              expect(space.isolation_segment_model).to eq(isolation_segment_model)
            end
          end
        end

        context 'when the specified segment does not exist' do
          context 'as an admin who is not a manager' do
            before do
              set_current_user_as_admin
            end

            it 'returns a 404 ResourceNotFound error' do
              put "/v2/spaces/#{space.guid}", MultiJson.dump({ isolation_segment_guid: 'bad-guid' })

              expect(last_response.status).to eq 404
              expect(decoded_response['error_code']).to eq 'CF-ResourceNotFound'
            end
          end

          context 'as an org manager' do
            before do
              space.organization.add_manager(user)
            end

            it 'returns a 404 ResourceNotFound error' do
              put "/v2/spaces/#{space.guid}", MultiJson.dump({ isolation_segment_guid: 'bad-guid' })

              expect(last_response.status).to eq 404
              expect(decoded_response['error_code']).to eq 'CF-ResourceNotFound'
            end
          end
        end

        context 'as a developer' do
          before do
            space.organization.add_user(user)
            space.add_developer(user)
          end

          it 'returns a 403' do
            put "/v2/spaces/#{space.guid}", MultiJson.dump({ isolation_segment_guid: 'bad-guid' })

            expect(last_response.status).to eq 403
          end
        end

        context 'as a space manager' do
          before do
            space.organization.add_user(user)
            space.add_manager(user)
          end

          it 'returns a 403' do
            put "/v2/spaces/#{space.guid}", MultiJson.dump({ isolation_segment_guid: 'bad-guid' })

            expect(last_response.status).to eq 403
          end
        end

        context 'as an auditor' do
          before do
            space.organization.add_user(user)
            space.add_auditor(user)
          end

          it 'returns a 403' do
            put "/v2/spaces/#{space.guid}", MultiJson.dump({ isolation_segment_guid: 'bad-guid' })

            expect(last_response.status).to eq 403
          end
        end
      end

      context 'setting roles at space update time' do
        let(:other_user) { User.make }
        let(:uri) { "/v2/spaces/#{space.guid}" }

        before do
          set_current_user_as_admin
          space.organization.add_user(other_user)
        end

        context 'assigning a space manager' do
          it 'records an event of type audit.user.space_manager_add' do
            event = Event.find(type: 'audit.user.space_manager_add', actee: other_user.guid)
            expect(event).to be_nil

            request_body = { manager_guids: [other_user.guid] }.to_json
            put uri, request_body

            expect(last_response).to have_status_code(201)

            expect(space.managers).to include(other_user)

            event = Event.find(type: 'audit.user.space_manager_add', actee: other_user.guid)
            expect(event).not_to be_nil
          end

          context 'when there is already another space manager' do
            let(:mgr) { User.make }

            before do
              space.organization.add_user(mgr)
              space.add_manager(mgr)
            end

            it 'does not record an event for existing space managers' do
              request_body = { manager_guids: [other_user.guid, mgr.guid] }.to_json
              put uri, request_body

              expect(last_response).to have_status_code(201)

              event = Event.find(type: 'audit.user.space_manager_add', actee: mgr.guid)
              expect(event).to be_nil
            end
          end
        end

        context 'deassigning an space manager' do
          let(:another_user) { User.make }

          before do
            space.organization.add_user(another_user)
            space.add_manager(other_user)
            space.add_manager(another_user)
          end

          it 'records an event of type audit.user.space_manager_remove' do
            event = Event.find(type: 'audit.user.space_manager_remove', actee: other_user.guid)
            expect(event).to be_nil

            request_body = { manager_guids: [another_user.guid] }.to_json
            put uri, request_body

            expect(last_response).to have_status_code(201)
            space.reload
            expect(space.managers).to_not include(other_user)

            event = Event.find(type: 'audit.user.space_manager_remove', actee: other_user.guid)
            expect(event).not_to be_nil
          end
        end

        context 'assigning an auditor' do
          it 'records an event of type audit.user.space_auditor_add' do
            event = Event.find(type: 'audit.user.space_auditor_add', actee: other_user.guid)
            expect(event).to be_nil

            request_body = { auditor_guids: [other_user.guid] }.to_json
            put uri, request_body

            expect(last_response).to have_status_code(201)

            expect(space.auditors).to include(other_user)

            event = Event.find(type: 'audit.user.space_auditor_add', actee: other_user.guid)
            expect(event).not_to be_nil
          end
        end

        context 'deassigning an auditor' do
          before do
            space.add_auditor(other_user)
          end

          it 'records an event of type audit.user.space_auditor_remove' do
            event = Event.find(type: 'audit.user.space_auditor_remove', actee: other_user.guid)
            expect(event).to be_nil

            request_body = { auditor_guids: [] }.to_json
            put uri, request_body

            expect(last_response).to have_status_code(201)
            space.reload
            expect(space.auditors).to_not include(other_user)

            event = Event.find(type: 'audit.user.space_auditor_remove', actee: other_user.guid)
            expect(event).not_to be_nil
          end
        end

        context 'assigning a developer' do
          it 'records an event of type audit.user.space_developer_add' do
            event = Event.find(type: 'audit.user.space_developer_add', actee: other_user.guid)
            expect(event).to be_nil

            request_body = { developer_guids: [other_user.guid] }.to_json
            put uri, request_body

            expect(last_response).to have_status_code(201)

            expect(space.developers).to include(other_user)

            event = Event.find(type: 'audit.user.space_developer_add', actee: other_user.guid)
            expect(event).not_to be_nil
          end
        end

        context 'removing a developer' do
          before do
            space.add_developer(other_user)
          end

          it 'records an event of type audit.user.space_developer_remove' do
            event = Event.find(type: 'audit.user.space_developer_remove', actee: other_user.guid)
            expect(event).to be_nil

            request_body = { developer_guids: [] }.to_json
            put uri, request_body

            expect(last_response).to have_status_code(201)
            space.reload
            expect(space.developers).to_not include(other_user)

            event = Event.find(type: 'audit.user.space_developer_remove', actee: other_user.guid)
            expect(event).not_to be_nil
          end
        end
      end
    end

    describe 'DELETE /v2/spaces/:guid/isolation_segment' do
      let(:assigner) { IsolationSegmentAssign.new }
      let(:user) { set_current_user(User.make) }
      let(:isolation_segment_model) { IsolationSegmentModel.make }
      let(:organization) { Organization.make }
      let(:space) { Space.make(organization: organization) }

      before do
        assigner.assign(isolation_segment_model, [organization])
      end

      context 'as a developer' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'fails with a 403' do
          delete "/v2/spaces/#{space.guid}/isolation_segment"
          expect(last_response.status).to eq 403
        end
      end

      context 'as a space manager' do
        before do
          space.organization.add_user(user)
          space.add_manager(user)
        end

        it 'fails with a 403' do
          delete "/v2/spaces/#{space.guid}/isolation_segment"
          expect(last_response.status).to eq 403
        end
      end

      context 'as an auditor' do
        before do
          space.organization.add_user(user)
          space.add_auditor(user)
        end

        it 'fails with a 403' do
          delete "/v2/spaces/#{space.guid}/isolation_segment"
          expect(last_response.status).to eq 403
        end
      end

      context 'when the space is not associated to an isolation segment' do
        context 'as an admin who is not a manager' do
          before do
            set_current_user_as_admin
          end

          it 'successfully removes the isolation segment' do
            delete "/v2/spaces/#{space.guid}/isolation_segment"
            expect(last_response.status).to eq 200
          end
        end

        context 'as an org manager' do
          before do
            organization.add_manager(user)
          end

          it 'successfully removes the isolation segment' do
            delete "/v2/spaces/#{space.guid}/isolation_segment"
            expect(last_response.status).to eq 200
          end
        end
      end

      context 'when a space is associated with an isolation segment' do
        before do
          space.isolation_segment_guid = isolation_segment_model.guid
          space.save
        end

        context 'and we have permission' do
          before do
            set_current_user_as_admin
          end

          it 'successfully removes the isolation segment' do
            delete "/v2/spaces/#{space.guid}/isolation_segment"
            expect(last_response.status).to eq 200

            space.reload
            expect(space.isolation_segment_model).to be_nil
          end
        end
      end
    end

    describe 'security groups' do
      let(:user) { User.make }
      let(:org) { Organization.make(user_guids: [user.guid]) }
      let(:space) { Space.make(organization: org) }
      let(:security_group) { SecurityGroup.make }

      before do
        set_current_user(user)
      end

      context 'as admin' do
        before do
          set_current_user_as_admin(user: user)
        end

        it 'works for staging security groups' do
          put "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 201

          get "/v2/spaces/#{space.guid}/staging_security_groups", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(security_group.guid)

          delete "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 204
        end

        it 'works for running security groups' do
          put "/v2/spaces/#{space.guid}/security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 201

          get "/v2/spaces/#{space.guid}/security_groups", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(security_group.guid)

          delete "/v2/spaces/#{space.guid}/security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 204
        end
      end

      context 'as org manager' do
        before do
          org.add_manager(user)
        end

        it 'works for staging security groups' do
          put "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 201

          get "/v2/spaces/#{space.guid}/staging_security_groups", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(security_group.guid)

          delete "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 204
        end

        it 'works for running security groups' do
          put "/v2/spaces/#{space.guid}/security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 201

          get "/v2/spaces/#{space.guid}/security_groups", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(security_group.guid)

          delete "/v2/spaces/#{space.guid}/security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 204
        end
      end

      context 'as space manager' do
        before do
          space.add_manager(user)
        end

        it 'works for staging security groups' do
          put "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 201

          get "/v2/spaces/#{space.guid}/staging_security_groups", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(security_group.guid)

          delete "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 204
        end

        it 'works for running security groups' do
          put "/v2/spaces/#{space.guid}/security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 201

          get "/v2/spaces/#{space.guid}/security_groups", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(security_group.guid)

          delete "/v2/spaces/#{space.guid}/security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 204
        end
      end

      context 'as space developer' do
        before do
          space.add_developer(user)
        end

        it 'works for staging security groups' do
          put "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 403

          space.add_staging_security_group(security_group)

          get "/v2/spaces/#{space.guid}/staging_security_groups", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(security_group.guid)

          delete "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 403
        end

        it 'works for running security groups' do
          put "/v2/spaces/#{space.guid}/security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 403

          space.add_security_group(security_group)

          get "/v2/spaces/#{space.guid}/security_groups", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(security_group.guid)

          delete "/v2/spaces/#{space.guid}/security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 403
        end
      end

      context 'as space auditor' do
        before do
          space.add_auditor(user)
        end

        it 'works for staging security groups' do
          put "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 403

          space.add_staging_security_group(security_group)

          get "/v2/spaces/#{space.guid}/staging_security_groups", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(security_group.guid)

          delete "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 403
        end

        it 'works for running security groups' do
          put "/v2/spaces/#{space.guid}/security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 403

          space.add_security_group(security_group)

          get "/v2/spaces/#{space.guid}/security_groups", nil
          expect(last_response.status).to eq 200
          expect(last_response.body).to include(security_group.guid)

          delete "/v2/spaces/#{space.guid}/security_groups/#{security_group.guid}", nil
          expect(last_response.status).to eq 403
        end
      end
    end

    describe 'adding user roles by username' do
      [:manager, :developer, :auditor].each do |role|
        plural_role = role.to_s.pluralize
        describe "PUT /v2/spaces/:guid/#{plural_role}" do
          let(:user) { User.make(username: 'larry_the_user') }
          let(:event_type) { "audit.user.space_#{role}_add" }

          before do
            allow_any_instance_of(UaaClient).to receive(:id_for_username).with(user.username).and_return(user.guid)
            organization_one.add_user(user)
            set_current_user_as_admin(email: user_email)
          end

          it "makes the user a space #{role}" do
            put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

            expect(last_response.status).to eq(201)
            expect(space_one.send(plural_role)).to include(user)
            expect(decoded_response['metadata']['guid']).to eq(space_one.guid)
          end

          it 'verifies the user has update access to the space' do
            expect_any_instance_of(SpacesController).to receive(:find_guid_and_validate_access).with(:update, space_one.guid).and_call_original
            put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })
          end

          it 'returns a 404 when the user does not exist in UAA' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).with('fake@example.com').and_return(nil)

            put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: 'fake@example.com' })

            expect(last_response.status).to eq(404)
            expect(decoded_response['code']).to eq(20003)
          end

          it 'returns an error when UAA is not available' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaUnavailable)

            put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

            expect(last_response.status).to eq(503)
            expect(decoded_response['code']).to eq(20004)
          end

          it 'returns an error when UAA endpoint is disabled' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaEndpointDisabled)

            put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

            expect(last_response.status).to eq(501)
            expect(decoded_response['code']).to eq(20005)
          end

          it 'logs audit.space.role.add when a role is associated to a space' do
            put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

            event = Event.find(type: event_type, actee: user.guid)
            expect(event).not_to be_nil
            expect(event.space_guid).to eq(space_one.guid)
            expect(event.actor_name).to eq(SecurityContext.current_user_email)
            expect(event.organization_guid).to eq(space_one.organization.guid)
          end

          context 'when the feature flag "set_roles_by_username" is disabled' do
            before do
              FeatureFlag.new(name: 'set_roles_by_username', enabled: false).save
            end

            it 'raises a feature flag error for non-admins' do
              set_current_user(user)
              put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

              expect(last_response.status).to eq(403)
              expect(decoded_response['code']).to eq(330002)
            end

            it 'succeeds for admins' do
              put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

              expect(last_response.status).to eq(201)
              expect(space_one.send(plural_role)).to include(user)
              expect(decoded_response['metadata']['guid']).to eq(space_one.guid)
            end
          end
        end
      end
    end

    describe 'removing user roles by username' do
      [:manager, :developer, :auditor].each do |role|
        plural_role = role.to_s.pluralize
        describe "DELETE /v2/spaces/:guid/#{plural_role}" do
          let(:user) { User.make(username: 'larry_the_user') }
          let(:event_type) { "audit.user.space_#{role}_remove" }

          before do
            allow_any_instance_of(UaaClient).to receive(:id_for_username).with(user.username).and_return(user.guid)
            organization_one.add_user(user)
            space_one.send("add_#{role}", user)
            set_current_user_as_admin(email: user_email)
          end

          it "unsets the user as a space #{role}" do
            expect(space_one.send(plural_role)).to include(user)

            delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

            expect(last_response.status).to eq(200)
            expect(space_one.reload.send(plural_role)).to_not include(user)
            expect(decoded_response['metadata']['guid']).to eq(space_one.guid)
          end

          it 'verifies the user has update access to the space' do
            expect_any_instance_of(SpacesController).to receive(:find_guid_and_validate_access).with(:update, space_one.guid).and_call_original
            delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })
          end

          it 'returns a 404 when the user does not exist in CC' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).with('fake@example.com').and_return('not-a-real-guid')

            delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: 'fake@example.com' })

            expect(last_response.status).to eq(404)
            expect(decoded_response['code']).to eq(20003)
          end

          it 'returns an error when UAA is not available' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaUnavailable)

            delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

            expect(last_response.status).to eq(503)
            expect(decoded_response['code']).to eq(20004)
          end

          it 'returns an error when UAA endpoint is disabled' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaEndpointDisabled)

            delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

            expect(last_response.status).to eq(501)
            expect(decoded_response['code']).to eq(20005)
          end

          it 'logs audit.space.role.remove when a user-role association is removed from a space' do
            delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

            event = Event.find(type: event_type, actee: user.guid)
            expect(event).not_to be_nil
            expect(event.space_guid).to eq(space_one.guid)
            expect(event.actor_name).to eq(SecurityContext.current_user_email)
            expect(event.organization_guid).to eq(space_one.organization.guid)
          end

          context 'when the feature flag "unset_roles_by_username" is disabled' do
            before do
              FeatureFlag.new(name: 'unset_roles_by_username', enabled: false).save
            end

            it 'raises a feature flag error for non-admins' do
              set_current_user(user)
              delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

              expect(last_response.status).to eq(403)
              expect(decoded_response['code']).to eq(330002)
            end

            it 'succeeds for admins' do
              expect(space_one.send(plural_role)).to include(user)

              delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username })

              expect(last_response.status).to eq(200)
              expect(space_one.reload.send(plural_role)).to_not include(user)
              expect(decoded_response['metadata']['guid']).to eq(space_one.guid)
            end
          end
        end
      end
    end

    describe 'adding user roles by user_id' do
      [:manager, :developer, :auditor].each do |role|
        plural_role = role.to_s.pluralize
        describe "PUT /v2/spaces/:guid/#{plural_role}/:user_guid" do
          let(:user) { User.make(username: 'larry_the_user') }
          let(:space) { Space.make }
          let(:event_type) { "audit.user.space_#{role}_add" }

          before do
            space.organization.add_user(user)
            set_current_user_as_admin(email: user_email)
            allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).and_return({ user.guid => user.username })
          end

          it "makes the user a space #{role}" do
            put "/v2/spaces/#{space.guid}/#{plural_role}/#{user.guid}"

            expect(last_response.status).to eq(201)
            expect(space.send(plural_role)).to include(user)
            expect(decoded_response['metadata']['guid']).to eq(space.guid)
          end

          it 'verifies the user has update access to the space' do
            expect_any_instance_of(SpacesController).to receive(:find_guid_and_validate_access).with(:update, space.guid).and_call_original
            put "/v2/spaces/#{space.guid}/#{plural_role}/#{user.guid}"
          end

          it 'returns a 400 when the user does not exist' do
            put "/v2/spaces/#{space.guid}/#{plural_role}/bogus-user-id"

            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(1002)
          end

          it 'logs audit.space.role.add when a role is associated to a space' do
            put "/v2/spaces/#{space.guid}/#{plural_role}/#{user.guid}"

            event = Event.find(type: event_type, actee: user.guid)
            expect(event).not_to be_nil
            expect(event.space_guid).to eq(space.guid)
            expect(event.actor_name).to eq(SecurityContext.current_user_email)
            expect(event.organization_guid).to eq(space.organization.guid)
          end
        end
      end
    end

    describe 'removing user roles by user_id' do
      [:manager, :developer, :auditor].each do |role|
        plural_role = role.to_s.pluralize
        describe "DELETE /v2/spaces/:guid/#{plural_role}/:user_guid" do
          let(:user) { User.make(username: 'larry_the_user') }
          let(:space) { Space.make }
          let(:event_type) { "audit.user.space_#{role}_remove" }

          before do
            space.organization.add_user(user)
            space.send("add_#{role}", user)
            set_current_user_as_admin(email: user_email)
            allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).with([user.guid]).and_return({ user.guid => user.username })
          end

          it "unsets the user as a space #{role}" do
            expect(space.send(plural_role)).to include(user)

            delete "/v2/spaces/#{space.guid}/#{plural_role}/#{user.guid}"

            expect(last_response.status).to eq(204)
            expect(space.reload.send(plural_role)).to_not include(user)
          end

          it 'verifies the user has update access to the space' do
            expect_any_instance_of(SpacesController).to receive(:find_guid_and_validate_access).with(:update, space.guid).and_call_original
            delete "/v2/spaces/#{space.guid}/#{plural_role}/#{user.guid}"
          end

          it 'returns a 400 when the user does not exist in CC' do
            allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).and_return({})
            delete "/v2/spaces/#{space.guid}/#{plural_role}/bogus-user-id"

            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(1002)
          end

          it 'logs audit.space.role.remove when a user-role association is removed from a space' do
            delete "/v2/spaces/#{space.guid}/#{plural_role}/#{user.guid}"

            event = Event.find(type: event_type, actee: user.guid)
            expect(event).not_to be_nil
            expect(event.space_guid).to eq(space.guid)
            expect(event.actor_name).to eq(SecurityContext.current_user_email)
            expect(event.organization_guid).to eq(space.organization.guid)
          end
        end
      end
    end

    describe 'Deprecated endpoints' do
      let!(:domain) { SharedDomain.make }
      describe 'DELETE /v2/spaces/:guid/domains/:shared_domain' do
        it 'should pretends that it deleted a domain' do
          delete "/v2/spaces/#{space_one.guid}/domains/#{domain.guid}"
          expect(last_response).to be_a_deprecated_response
        end
      end

      describe 'GET /v2/organizations/:guid/domains/:guid' do
        it 'should be deprecated' do
          get "/v2/spaces/#{space_one.guid}/domains/#{domain.guid}"
          expect(last_response).to be_a_deprecated_response
        end
      end
    end
  end
end
