require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::SpacesController do
    let(:organization_one) { Organization.make }
    let(:space_one) { Space.make(organization: organization_one) }

    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
      it { expect(described_class).to be_queryable_by(:organization_guid) }
      it { expect(described_class).to be_queryable_by(:developer_guid) }
      it { expect(described_class).to be_queryable_by(:app_guid) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name:                   { type: 'string', required: true },
          allow_ssh:              { type: 'bool', default: true },
          organization_guid:      { type: 'string', required: true },
          developer_guids:        { type: '[string]' },
          manager_guids:          { type: '[string]' },
          auditor_guids:          { type: '[string]' },
          domain_guids:           { type: '[string]' },
          service_instance_guids: { type: '[string]' },
          security_group_guids:   { type: '[string]' },
          space_quota_definition_guid: { type: 'string' }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name:                   { type: 'string' },
          allow_ssh:              { type: 'bool' },
          organization_guid:      { type: 'string' },
          developer_guids:        { type: '[string]' },
          manager_guids:          { type: '[string]' },
          auditor_guids:          { type: '[string]' },
          domain_guids:           { type: '[string]' },
          service_instance_guids: { type: '[string]' },
          security_group_guids:   { type: '[string]' },
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
      it do
        expect(described_class).to have_nested_routes(
          {
            developers:        [:get, :put, :delete],
            managers:          [:get, :put, :delete],
            auditors:          [:get, :put, :delete],
            apps:              [:get],
            routes:            [:get],
            domains:           [:get, :put, :delete],
            service_instances: [:get],
            app_events:        [:get],
            events:            [:get],
            security_groups:   [:get, :put, :delete],
          })
      end

      describe 'app_events associations' do
        it 'does not return app_events with inline-relations-depth=0' do
          space = Space.make
          get "/v2/spaces/#{space.guid}?inline-relations-depth=0", {}, json_headers(admin_headers)
          expect(entity).to have_key('app_events_url')
          expect(entity).to_not have_key('app_events')
        end

        it 'does not return app_events with inline-relations-depth=1 since app_events dataset is relatively expensive to query' do
          space = Space.make
          get "/v2/spaces/#{space.guid}?inline-relations-depth=1", {}, json_headers(admin_headers)
          expect(entity).to have_key('app_events_url')
          expect(entity).to_not have_key('app_events')
        end
      end

      describe 'events associations' do
        it 'does not return events with inline-relations-depth=0' do
          space = Space.make
          get "/v2/spaces/#{space.guid}?inline-relations-depth=0", {}, json_headers(admin_headers)
          expect(entity).to have_key('events_url')
          expect(entity).to_not have_key('events')
        end

        it 'does not return events with inline-relations-depth=1 since events dataset is relatively expensive to query' do
          space = Space.make
          get "/v2/spaces/#{space.guid}?inline-relations-depth=1", {}, json_headers(admin_headers)
          expect(entity).to have_key('events_url')
          expect(entity).to_not have_key('events')
        end
      end
    end

    describe 'GET /v2/spaces/:guid/user_roles' do
      context 'for an space that does not exist' do
        it 'returns a 404' do
          get '/v2/spaces/foobar/user_roles', {}, admin_headers
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the user does not have permissions to read' do
        let(:user) { User.make }

        it 'returns a 403' do
          get "/v2/spaces/#{space_one.guid}/user_roles", {}, headers_for(user)
          expect(last_response.status).to eq(403)
        end
      end
    end

    describe 'GET /v2/spaces/:guid/service_instances' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }

      context 'when filtering results' do
        it 'returns only matching results' do
          user_provided_service_instance_1 = UserProvidedServiceInstance.make(space: space, name: 'provided service 1')
          UserProvidedServiceInstance.make(space: space, name: 'provided service 2')
          managed_service_instance_1 = ManagedServiceInstance.make(space: space, name: 'managed service 1')
          ManagedServiceInstance.make(space: space, name: 'managed service 2')

          get "v2/spaces/#{space.guid}/service_instances", { 'q' => 'name:provided service 1;', 'return_user_provided_service_instances' => true }, headers_for(developer)
          guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
          expect(guids).to eq([user_provided_service_instance_1.guid])

          get "v2/spaces/#{space.guid}/service_instances", { 'q' => 'name:managed service 1;', 'return_user_provided_service_instances' => true }, headers_for(developer)
          guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
          expect(guids).to eq([managed_service_instance_1.guid])
        end
      end

      context 'when there are provided service instances' do
        let!(:user_provided_service_instance) { UserProvidedServiceInstance.make(space: space) }
        let!(:managed_service_instance) { ManagedServiceInstance.make(space: space) }

        describe 'when return_user_provided_service_instances is true' do
          it 'returns ManagedServiceInstances and UserProvidedServiceInstances' do
            get "v2/spaces/#{space.guid}/service_instances", { return_user_provided_service_instances: true }, headers_for(developer)

            guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
            expect(guids).to include(user_provided_service_instance.guid, managed_service_instance.guid)
          end

          it 'includes service_plan_url for managed service instances' do
            get "/v2/spaces/#{space.guid}/service_instances", { return_user_provided_service_instances: true }, headers_for(developer)
            service_instances_response = decoded_response.fetch('resources')
            managed_service_instance_response = service_instances_response.detect {|si|
              si.fetch('metadata').fetch('guid') == managed_service_instance.guid
            }
            expect(managed_service_instance_response.fetch('entity').fetch('service_plan_url')).to be
            expect(managed_service_instance_response.fetch('entity').fetch('space_url')).to be
            expect(managed_service_instance_response.fetch('entity').fetch('service_bindings_url')).to be
          end

          it 'includes the correct service binding url' do
            get "/v2/spaces/#{space.guid}/service_instances", { return_user_provided_service_instances: true }, headers_for(developer)
            service_instances_response = decoded_response.fetch('resources')
            user_provided_service_instance_response = service_instances_response.detect {|si|
              si.fetch('metadata').fetch('guid') == user_provided_service_instance.guid
            }
            expect(user_provided_service_instance_response.fetch('entity').fetch('service_bindings_url')).to include('user_provided_service_instance')
          end
        end

        describe 'when return_user_provided_service_instances flag is not present' do
          it 'returns only the managed service instances' do
            get "/v2/spaces/#{space.guid}/service_instances", '', headers_for(developer)
            guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
            expect(guids).to match_array([managed_service_instance.guid])
          end

          it 'includes service_plan_url for managed service instances' do
            get "/v2/spaces/#{space.guid}/service_instances", '', headers_for(developer)
            service_instances_response = decoded_response.fetch('resources')
            managed_service_instance_response = service_instances_response.detect {|si|
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
              get "/v2/spaces/#{@space_a.guid}/service_instances", {}, headers_for(member_a)

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
            get path, {}, headers_for(member_a)

            expect(last_response).to be_ok
            expect(decoded_response['total_results']).to eq(expected)
            guids = decoded_response['resources'].map { |o| o['metadata']['guid'] }
            expect(guids).to include(managed_service_instance.guid) if expected > 0
          end

          it "should not return a service instance to a user with the #{perm_name} permission on a different space" do
            get path, {}, headers_for(member_b)
            expect(last_response).to have_status_code(403)
          end
        end

        shared_examples 'disallow enumerating services' do |perm_name|
          describe 'disallowing enumerating services' do
            it "disallows a user that only has #{perm_name} permission on the space" do
              get "/v2/spaces/#{@space_a.guid}/services", {}, headers_for(member_a)

              expect(last_response).to be_forbidden
            end
          end
        end

        shared_examples 'enumerating services' do |perm_name, opts|
          let(:path) { "/v2/spaces/#{@space_a.guid}/services" }

          it "should return services to a user that has #{perm_name} permissions" do
            get path, {}, headers_for(member_a)

            expect(last_response).to be_ok
          end

          it "should not return services to a user with the #{perm_name} permission on a different space" do
            get path, {}, headers_for(member_b)
            expect(last_response).to be_forbidden
          end
        end

        describe 'Org Level' do
          describe 'OrgManager' do
            it_behaves_like(
              'enumerating service instances', 'OrgManager',
              expected: 0,
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
      let(:headers) { headers_for(user)  }

      before do
        user.add_organization(organization_two)
        space_two.add_developer(user)
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
          developer_headers = headers_for(developer)
          get "v2/spaces/#{space_one.guid}/services", {}, developer_headers
          expect(decoded_guids).to include(@service.guid)
        end

        it 'should not be visible to outside SpaceDevelopers, even in their own space' do
          developer_headers = headers_for(outside_developer)
          get "v2/spaces/#{space_two.guid}/services", {}, developer_headers
          expect(decoded_guids).not_to include(@service.guid)
        end

        it 'should be visible to SpaceManagers ' do
          manager_headers = headers_for(manager)
          get "v2/spaces/#{space_one.guid}/services", {}, manager_headers
          expect(decoded_guids).to include(@service.guid)
        end

        it 'should be visible to SpaceManagers' do
          manager_headers = headers_for(outside_manager)
          get "v2/spaces/#{space_one.guid}/services", {}, manager_headers
          expect(last_response).not_to be_ok
        end

        it 'should be visible to SpaceAuditor' do
          auditor_headers = headers_for(auditor)
          get "v2/spaces/#{space_one.guid}/services", {}, auditor_headers
          expect(decoded_guids).to include(@service.guid)
        end

        it 'should be visible to SpaceManagers' do
          auditor_headers = headers_for(outside_auditor)
          get "v2/spaces/#{space_one.guid}/services", {}, auditor_headers
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
          get "/v2/spaces/#{space_two.guid}/services", {}, headers
          expect(last_response).to be_ok
          expect(decoded_guids).not_to include(@service.guid)
        end

        it "should return the offering when the org has access to one of the service's plans" do
          get "/v2/spaces/#{space_one.guid}/services", {}, headers
          expect(last_response).to be_ok
          expect(decoded_guids).to include(@service.guid)
        end

        it 'should include plans that are visible to the org' do
          get "/v2/spaces/#{space_one.guid}/services?inline-relations-depth=1", {}, headers

          expect(last_response).to be_ok
          service = decoded_response.fetch('resources').fetch(0)
          service_plans = service.fetch('entity').fetch('service_plans')
          expect(service_plans.length).to eq(1)
          expect(service_plans.first.fetch('metadata').fetch('guid')).to eq(@service_plan.guid)
          expect(service_plans.first.fetch('metadata').fetch('url')).to eq("/v2/service_plans/#{@service_plan.guid}")
        end

        it 'should exclude plans that are not visible to the org' do
          public_service_plan = ServicePlan.make(service: @service, public: true)

          get "/v2/spaces/#{space_two.guid}/services?inline-relations-depth=1", {}, headers

          expect(last_response).to be_ok
          service = decoded_response.fetch('resources').fetch(0)
          service_plans = service.fetch('entity').fetch('service_plans')
          expect(service_plans.length).to eq(1)
          expect(service_plans.first.fetch('metadata').fetch('guid')).to eq(public_service_plan.guid)
        end
      end

      describe 'get /v2/spaces/:guid/services?q=active:<t|f>' do
        before(:each) do
          @active = 3.times.map { Service.make(active: true).tap { |svc| ServicePlan.make(service: svc) } }
          @inactive = 2.times.map { Service.make(active: false).tap { |svc| ServicePlan.make(service: svc) } }
        end

        it 'can remove inactive services' do
          get "/v2/spaces/#{space_one.guid}/services?q=active:t", {}, headers
          expect(last_response).to be_ok
          expect(decoded_guids).to match_array(@active.map(&:guid))
        end

        it 'can only get inactive services' do
          get "/v2/spaces/#{space_one.guid}/services?q=active:f", {}, headers
          expect(last_response).to be_ok
          expect(decoded_guids).to match_array(@inactive.map(&:guid))
        end
      end
    end

    describe 'audit events' do
      let(:organization) { Organization.make }

      it 'logs audit.space.create when creating a space' do
        request_body = { organization_guid: organization.guid, name: 'space_name' }.to_json
        post '/v2/spaces', request_body, json_headers(admin_headers)

        expect(last_response).to have_status_code(201)

        new_space_guid = decoded_response['metadata']['guid']
        event = Event.find(type: 'audit.space.create', actee: new_space_guid)
        expect(event).not_to be_nil
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
        expect(event.metadata['request']).to include('organization_guid' => organization.guid, 'name' => 'space_name')
      end

      it 'logs audit.space.update when updating a space' do
        space = Space.make
        request_body = { name: 'new_space_name' }.to_json
        put "/v2/spaces/#{space.guid}", request_body, json_headers(admin_headers)

        expect(last_response).to have_status_code(201)

        space_guid = decoded_response['metadata']['guid']
        event = Event.find(type: 'audit.space.update', actee: space_guid)
        expect(event).not_to be_nil
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
        expect(event.metadata['request']).to eq('name' => 'new_space_name')
      end

      it 'logs audit.space.delete-request when deleting a space' do
        space = Space.make
        organization_guid = space.organization.guid
        space_guid = space.guid
        delete "/v2/spaces/#{space_guid}?recursive=true", '', json_headers(admin_headers)

        expect(last_response).to have_status_code(204)

        event = Event.find(type: 'audit.space.delete-request', actee: space_guid)
        expect(event).not_to be_nil
        expect(event.metadata['request']).to eq('recursive' => true)
        expect(event.space_guid).to eq(space_guid)
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
        expect(event.organization_guid).to eq(organization_guid)
      end
    end

    describe 'DELETE /v2/spaces/:guid' do
      context 'when recursive is false' do
        it 'successfully deletes spaces with no associations' do
          space_guid = Space.make.guid
          delete "/v2/spaces/#{space_guid}", '', json_headers(admin_headers)

          expect(last_response).to have_status_code(204)
          expect(Space.find(guid: space_guid)).to be_nil
        end

        it 'fails to delete spaces with v3 apps associated to it' do
          space_guid = Space.make.guid
          AppModel.make(space_guid: space_guid)
          delete "/v2/spaces/#{space_guid}", '', json_headers(admin_headers)

          expect(last_response).to have_status_code(400)
          expect(Space.find(guid: space_guid)).not_to be_nil
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
        end

        it 'successfully deletes spaces with v3 app associations' do
          delete "/v2/spaces/#{space_guid}?recursive=true", '', json_headers(admin_headers)

          expect(last_response).to have_status_code(204)
          expect(Space.find(guid: space_guid)).to be_nil
          expect(AppModel.find(guid: app_guid)).to be_nil
          expect(Route.find(guid: route_guid)).to be_nil
        end

        it 'successfully deletes the space in a background job when async=true' do
          delete "/v2/spaces/#{space_guid}?recursive=true&async=true", '', json_headers(admin_headers)

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
          delete "/v2/spaces/#{space_guid}?recursive=true", '', headers_for(user, email: 'user@email.com')

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
            delete "/v2/spaces/#{space_guid}?recursive=true&async=true", '', json_headers(admin_headers)
            expect(last_response).to have_status_code(202)
            job_guid = decoded_response['metadata']['guid']

            expect(Delayed::Worker.new.work_off).to eq([0, 1])

            get "/v2/jobs/#{job_guid}", {}, json_headers(admin_headers)
            expect(decoded_response['entity']['status']).to eq 'failed'
            expect(decoded_response['entity']['error_details']['error_code']).to eq 'CF-SpaceDeleteTimeout'
          end
        end

        describe 'deleting service instances' do
          let(:app_model) { AppFactory.make(space_guid: space_guid) }

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
            delete "/v2/spaces/#{space_guid}?recursive=true", '', json_headers(admin_headers)

            expect(last_response).to have_status_code(204)
            expect(service_instance_1.exists?).to be_falsey
            expect(service_instance_2.exists?).to be_falsey
            expect(service_instance_3.exists?).to be_falsey
          end

          it 'successfully deletes spaces with user_provided service instances' do
            delete "/v2/spaces/#{space_guid}?recursive=true", '', json_headers(admin_headers)

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
              delete "/v2/spaces/#{space_guid}?recursive=true", '', json_headers(admin_headers)

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
                delete "/v2/spaces/#{space_guid}?recursive=true", '', json_headers(admin_headers)
              }.to_not change { App.count }
            end

            it 'deletes all the v3 apps' do
              expect {
                delete "/v2/spaces/#{space_guid}?recursive=true", '', json_headers(admin_headers)
              }.to change { AppModel.count }.by(-1)
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
                delete "/v2/spaces/#{space_guid}?recursive=true", '', json_headers(admin_headers)

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
                delete "/v2/spaces/#{space_guid}?recursive=true&async=true", '', json_headers(admin_headers)
                expect(last_response).to have_status_code 202
                job_url = MultiJson.load(last_response.body)['metadata']['url']

                Delayed::Worker.new.work_off

                space_delete_jobs = Delayed::Job.where("handler like '%SpaceDelete%'")
                expect(space_delete_jobs.count).to eq 1
                expect(space_delete_jobs.first.last_error).not_to be_nil

                get job_url, {}, json_headers(admin_headers)
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
              delete "/v2/spaces/#{space_guid}?recursive=true", '', json_headers(admin_headers)
              expect(last_response).to have_status_code 502
              expect(decoded_response['error_code']).to eq 'CF-SpaceDeletionFailed'
              expect(last_response.body).to match /An operation for service instance #{service_instance_1.name} is in progress./
            end

            it 'does not delete that instance' do
              delete "/v2/spaces/#{space_guid}?recursive=true", '', json_headers(admin_headers)
              expect(space.exists?).to be_truthy
              expect(service_instance_1.exists?).to be_truthy
            end

            it 'deletes the other service instances' do
              delete "/v2/spaces/#{space_guid}?recursive=true", '', json_headers(admin_headers)
              expect(service_instance_2.exists?).to be_falsey
              expect(service_instance_3.exists?).to be_falsey
              expect(user_provided_service_instance.exists?).to be_falsey
            end

            context 'when async=true' do
              it 'returns an error to the user' do
                delete "/v2/spaces/#{space_guid}?recursive=true&async=true", '', json_headers(admin_headers)
                expect(last_response).to have_status_code 202

                Delayed::Worker.new.work_off

                space_delete_jobs = Delayed::Job.where("handler like '%SpaceDelete%'")
                expect(space_delete_jobs.count).to eq 1
                expect(space_delete_jobs.first.last_error).not_to be_nil

                job_url = decoded_response['metadata']['url']

                get job_url, {}, json_headers(admin_headers)
                expect(last_response).to have_status_code 200
                expect(decoded_response['entity']['error_details']['error_code']).to eq 'CF-SpaceDeletionFailed'
                expect(decoded_response['entity']['error_details']['description']).to match /An operation for service instance #{service_instance_1.name} is in progress./
              end

              it 'does not delete that instance' do
                delete "/v2/spaces/#{space_guid}?recursive=true&async=true", '', json_headers(admin_headers)

                Delayed::Worker.new.work_off

                space_delete_jobs = Delayed::Job.where("handler like '%SpaceDelete%'")
                expect(space_delete_jobs.count).to eq 1
                expect(space_delete_jobs.first.last_error).not_to be_nil

                expect(space.exists?).to be_truthy
                expect(service_instance_1.exists?).to be_truthy
              end

              it 'deletes the other service instances' do
                delete "/v2/spaces/#{space_guid}?recursive=true&async=true", '', json_headers(admin_headers)

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
        get "/v2/spaces/#{space.guid}/developers", '', headers_for(mgr)
        expect(last_response).to have_status_code(200)
      end

      it 'allows space developers' do
        get "/v2/spaces/#{space.guid}/developers", '', headers_for(user)
        expect(last_response).to have_status_code(200)
      end
    end

    describe 'adding user roles by username' do
      [:manager, :developer, :auditor].each do |role|
        plural_role = role.to_s.pluralize
        describe "PUT /v2/spaces/:guid/#{plural_role}" do
          let(:user) { User.make(username: 'larry_the_user') }

          before do
            allow_any_instance_of(UaaClient).to receive(:id_for_username).with(user.username).and_return(user.guid)
            organization_one.add_user(user)
          end

          it "makes the user a space #{role}" do
            put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(201)
            expect(space_one.send(plural_role)).to include(user)
            expect(decoded_response['metadata']['guid']).to eq(space_one.guid)
          end

          it 'verifies the user has update access to the space' do
            expect_any_instance_of(SpacesController).to receive(:find_guid_and_validate_access).with(:update, space_one.guid).and_call_original
            put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers
          end

          it 'returns a 404 when the user does not exist in UAA' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).with('fake@example.com').and_return(nil)

            put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: 'fake@example.com' }), admin_headers

            expect(last_response.status).to eq(404)
            expect(decoded_response['code']).to eq(20003)
          end

          it 'returns an error when UAA is not available' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaUnavailable)

            put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(503)
            expect(decoded_response['code']).to eq(20004)
          end

          it 'returns an error when UAA endpoint is disabled' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaEndpointDisabled)

            put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(501)
            expect(decoded_response['code']).to eq(20005)
          end

          context 'when the feature flag "set_roles_by_username" is disabled' do
            before do
              FeatureFlag.new(name: 'set_roles_by_username', enabled: false).save
            end

            it 'raises a feature flag error for non-admins' do
              put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), headers_for(user)

              expect(last_response.status).to eq(403)
              expect(decoded_response['code']).to eq(330002)
            end

            it 'succeeds for admins' do
              put "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

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

          before do
            allow_any_instance_of(UaaClient).to receive(:id_for_username).with(user.username).and_return(user.guid)
            organization_one.add_user(user)
            space_one.send("add_#{role}", user)
          end

          it "unsets the user as a space #{role}" do
            expect(space_one.send(plural_role)).to include(user)

            delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(200)
            expect(space_one.reload.send(plural_role)).to_not include(user)
            expect(decoded_response['metadata']['guid']).to eq(space_one.guid)
          end

          it 'verifies the user has update access to the space' do
            expect_any_instance_of(SpacesController).to receive(:find_guid_and_validate_access).with(:update, space_one.guid).and_call_original
            delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers
          end

          it 'returns a 404 when the user does not exist in CC' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).with('fake@example.com').and_return('not-a-real-guid')

            delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: 'fake@example.com' }), admin_headers

            expect(last_response.status).to eq(404)
            expect(decoded_response['code']).to eq(20003)
          end

          it 'returns an error when UAA is not available' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaUnavailable)

            delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(503)
            expect(decoded_response['code']).to eq(20004)
          end

          it 'returns an error when UAA endpoint is disabled' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaEndpointDisabled)

            delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(501)
            expect(decoded_response['code']).to eq(20005)
          end

          context 'when the feature flag "unset_roles_by_username" is disabled' do
            before do
              FeatureFlag.new(name: 'unset_roles_by_username', enabled: false).save
            end

            it 'raises a feature flag error for non-admins' do
              delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), headers_for(user)

              expect(last_response.status).to eq(403)
              expect(decoded_response['code']).to eq(330002)
            end

            it 'succeeds for admins' do
              expect(space_one.send(plural_role)).to include(user)

              delete "/v2/spaces/#{space_one.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

              expect(last_response.status).to eq(200)
              expect(space_one.reload.send(plural_role)).to_not include(user)
              expect(decoded_response['metadata']['guid']).to eq(space_one.guid)
            end
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
