require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::OrganizationsController do
    let(:org) { Organization.make }

    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
      it { expect(described_class).to be_queryable_by(:space_guid) }
      it { expect(described_class).to be_queryable_by(:user_guid) }
      it { expect(described_class).to be_queryable_by(:manager_guid) }
      it { expect(described_class).to be_queryable_by(:billing_manager_guid) }
      it { expect(described_class).to be_queryable_by(:auditor_guid) }
      it { expect(described_class).to be_queryable_by(:status) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes(
          {
            name:                  { type: 'string', required: true },
            billing_enabled:       { type: 'bool', default: false },
            status:                { type: 'string', default: 'active' },
            quota_definition_guid: { type: 'string' },
            user_guids:            { type: '[string]' },
            manager_guids:         { type: '[string]' },
            billing_manager_guids: { type: '[string]' },
            auditor_guids:         { type: '[string]' },
            app_event_guids:       { type: '[string]' }
          })
      end

      it do
        expect(described_class).to have_updatable_attributes(
          {
            name:                         { type: 'string' },
            billing_enabled:              { type: 'bool' },
            status:                       { type: 'string' },
            quota_definition_guid:        { type: 'string' },
            user_guids:                   { type: '[string]' },
            manager_guids:                { type: '[string]' },
            billing_manager_guids:        { type: '[string]' },
            auditor_guids:                { type: '[string]' },
            app_event_guids:              { type: '[string]' },
            space_guids:                  { type: '[string]' },
            space_quota_definition_guids: { type: '[string]' }
          })
      end
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        @obj_a = @org_a
        @obj_b = @org_b
      end

      describe 'Org Level Permissions' do
        describe 'OrgManager' do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples 'permission enumeration', 'OrgManager',
            name: 'organization',
            path: '/v2/organizations',
            enumerate: 1

          it 'cannot update quota definition' do
            quota = QuotaDefinition.make
            expect(@org_a.quota_definition.guid).to_not eq(quota.guid)

            put "/v2/organizations/#{@org_a.guid}", MultiJson.dump(quota_definition_guid: quota.guid), headers_a

            @org_a.reload
            expect(last_response.status).to eq(403)
            expect(@org_a.quota_definition.guid).to_not eq(quota.guid)
          end

          it 'cannot update billing_enabled' do
            billing_enabled_before = @org_a.billing_enabled

            put "/v2/organizations/#{@org_a.guid}", MultiJson.dump(billing_enabled: !billing_enabled_before), headers_a

            @org_a.reload
            expect(last_response.status).to eq(403)
            expect(@org_a.billing_enabled).to eq(billing_enabled_before)
          end
        end

        describe 'OrgUser' do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples 'permission enumeration', 'OrgUser',
            name: 'organization',
            path: '/v2/organizations',
            enumerate: 1
        end

        describe 'BillingManager' do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples 'permission enumeration', 'BillingManager',
            name: 'organization',
            path: '/v2/organizations',
            enumerate: 1
        end

        describe 'Auditor' do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples 'permission enumeration', 'Auditor',
            name: 'organization',
            path: '/v2/organizations',
            enumerate: 1
        end
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes(
          {
            spaces:                  [:get, :put, :delete],
            domains:                 [:get, :delete],
            private_domains:         [:get, :put, :delete],
            users:                   [:get, :put, :delete],
            managers:                [:get, :put, :delete],
            billing_managers:        [:get, :put, :delete],
            auditors:                [:get, :put, :delete],
            app_events:              [:get, :put, :delete],
            space_quota_definitions: [:get, :put, :delete],
          }
        )
      end
    end

    describe 'POST /v2/organizations' do
      context 'when user_org_creation feature_flag is disabled' do
        before do
          FeatureFlag.make(name: 'user_org_creation', enabled: false)
        end

        context 'as a non admin' do
          let(:user) { User.make }

          it 'returns FeatureDisabled' do
            post '/v2/organizations', MultiJson.dump({ name: 'my-org-name' }), headers_for(user)

            expect(last_response.status).to eq(403)
            expect(decoded_response['error_code']).to match(/CF-NotAuthorized/)
          end
        end

        context 'as an admin' do
          it 'does not add creator as an org manager' do
            post '/v2/organizations', MultiJson.dump({ name: 'my-org-name' }), admin_headers

            expect(last_response.status).to eq(201)
            org = Organization.find(name: 'my-org-name')
            expect(org.managers.count).to eq(0)
          end
        end
      end

      context 'when user_org_creation feature_flag is enabled' do
        before do
          FeatureFlag.make(name: 'user_org_creation', enabled: true)
        end

        context 'as a non admin' do
          let(:user) { User.make }

          it 'adds creator as an org manager' do
            post '/v2/organizations', MultiJson.dump({ name: 'my-org-name' }), headers_for(user)

            expect(last_response.status).to eq(201)
            org = Organization.find(name: 'my-org-name')
            expect(org.managers).to eq([user])
            expect(org.users).to eq([user])
          end
        end
      end
    end

    describe 'GET /v2/organizations/:guid/user_roles' do
      context 'for an organization that does not exist' do
        it 'returns a 404' do
          get '/v2/organizations/foobar/user_roles', {}, admin_headers
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the user does not have permissions to read' do
        let(:user) { User.make }

        it 'returns a 403' do
          get "/v2/organizations/#{org.guid}/user_roles", {}, headers_for(user)
          expect(last_response.status).to eq(403)
        end
      end
    end

    describe 'GET', '/v2/organizations/:guid/services' do
      let(:other_org) { Organization.make }
      let(:space_one) { Space.make(organization: org) }
      let(:user) { make_developer_for_space(space_one) }
      let(:headers) do
        headers_for(user)
      end

      before do
        user.add_organization(other_org)
        space_one.add_developer(user)
      end

      def decoded_guids
        decoded_response['resources'].map { |r| r['metadata']['guid'] }
      end

      context 'with an offering that has private plans' do
        before(:each) do
          @service = Service.make(active: true)
          @service_plan = ServicePlan.make(service: @service, public: false)
          ServicePlanVisibility.make(service_plan: @service.service_plans.first, organization: org)
        end

        it "should remove the offering when the org does not have access to any of the service's plans" do
          get "/v2/organizations/#{other_org.guid}/services", {}, headers
          expect(last_response).to be_ok
          expect(decoded_guids).not_to include(@service.guid)
        end

        it "should return the offering when the org has access to one of the service's plans" do
          get "/v2/organizations/#{org.guid}/services", {}, headers
          expect(last_response).to be_ok
          expect(decoded_guids).to include(@service.guid)
        end

        it 'should include plans that are visible to the org' do
          get "/v2/organizations/#{org.guid}/services?inline-relations-depth=1", {}, headers

          expect(last_response).to be_ok
          service = decoded_response.fetch('resources').fetch(0)
          service_plans = service.fetch('entity').fetch('service_plans')
          expect(service_plans.length).to eq(1)
          expect(service_plans.first.fetch('metadata').fetch('guid')).to eq(@service_plan.guid)
          expect(service_plans.first.fetch('metadata').fetch('url')).to eq("/v2/service_plans/#{@service_plan.guid}")
        end

        it 'should exclude plans that are not visible to the org' do
          public_service_plan = ServicePlan.make(service: @service, public: true)

          get "/v2/organizations/#{other_org.guid}/services?inline-relations-depth=1", {}, headers

          expect(last_response).to be_ok
          service = decoded_response.fetch('resources').fetch(0)
          service_plans = service.fetch('entity').fetch('service_plans')
          expect(service_plans.length).to eq(1)
          expect(service_plans.first.fetch('metadata').fetch('guid')).to eq(public_service_plan.guid)
        end
      end

      describe 'get /v2/organizations/:guid/services?q=active:<t|f>' do
        before(:each) do
          @active = 3.times.map { Service.make(active: true).tap { |svc| ServicePlan.make(service: svc) } }
          @inactive = 2.times.map { Service.make(active: false).tap { |svc| ServicePlan.make(service: svc) } }
        end

        it 'can remove inactive services' do
          get "/v2/organizations/#{org.guid}/services?q=active:t", {}, headers
          expect(last_response).to be_ok
          expect(decoded_guids).to match_array(@active.map(&:guid))
        end

        it 'can only get inactive services' do
          get "/v2/organizations/#{org.guid}/services?q=active:f", {}, headers
          expect(last_response).to be_ok
          expect(decoded_guids).to match_array(@inactive.map(&:guid))
        end
      end
    end

    describe 'GET /v2/organizations/:guid/memory_usage' do
      context 'for an organization that does not exist' do
        it 'returns a 404' do
          get '/v2/organizations/foobar/memory_usage', {}, admin_headers
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the user does not have permissions to read' do
        let(:user) { User.make }

        it 'returns a 403' do
          get "/v2/organizations/#{org.guid}/memory_usage", {}, headers_for(user)
          expect(last_response.status).to eq(403)
        end
      end

      it 'calls the organization memory usage calculator' do
        allow(OrganizationMemoryCalculator).to receive(:get_memory_usage).and_return(2)
        get "/v2/organizations/#{org.guid}/memory_usage", {}, admin_headers
        expect(last_response.status).to eq(200)
        expect(OrganizationMemoryCalculator).to have_received(:get_memory_usage).with(org)
        expect(MultiJson.load(last_response.body)).to eq({ 'memory_usage_in_mb' => 2 })
      end
    end

    describe 'GET /v2/organizations/:guid/instance_usage' do
      context 'for an organization that does not exist' do
        it 'returns a 404' do
          get '/v2/organizations/foobar/instance_usage', {}, admin_headers
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the user does not have permissions to read' do
        let(:user) { User.make }

        it 'returns a 403' do
          get "/v2/organizations/#{org.guid}/instance_usage", {}, headers_for(user)
          expect(last_response.status).to eq(403)
        end
      end

      it 'calls the organization instance usage calculator' do
        allow(OrganizationInstanceUsageCalculator).to receive(:get_instance_usage).and_return(2)
        get "/v2/organizations/#{org.guid}/instance_usage", {}, admin_headers
        expect(last_response.status).to eq(200)
        expect(OrganizationInstanceUsageCalculator).to have_received(:get_instance_usage).with(org)
        expect(MultiJson.load(last_response.body)).to eq({ 'instance_usage' => 2 })
      end
    end

    describe 'GET /v2/organizations/:guid/domains' do
      let(:organization) { Organization.make }
      let(:manager) { make_manager_for_org(organization) }

      before do
        PrivateDomain.make(owning_organization: organization)
      end

      it 'should return the private domains associated with the organization and all shared domains' do
        get "/v2/organizations/#{organization.guid}/domains", {}, headers_for(manager)
        expect(last_response.status).to eq(200)
        resources = decoded_response.fetch('resources')
        guids = resources.map { |x| x['metadata']['guid'] }
        expect(guids).to match_array(organization.domains.map(&:guid))
      end

      context 'space roles' do
        let(:organization) { Organization.make }
        let(:space) { Space.make(organization: organization) }

        context 'space developers without org role' do
          let(:space_developer) do
            make_developer_for_space(space)
          end

          it 'returns private domains' do
            private_domain = PrivateDomain.make(owning_organization: organization)
            get "/v2/organizations/#{organization.guid}/domains", {}, headers_for(space_developer)
            expect(last_response.status).to eq(200)
            guids = decoded_response.fetch('resources').map { |x| x['metadata']['guid'] }
            expect(guids).to include(private_domain.guid)
          end
        end
      end
    end

    describe 'Deprecated endpoints' do
      describe 'GET /v2/organizations/:guid/domains' do
        it 'should be deprecated' do
          get "/v2/organizations/#{org.guid}/domains", '', admin_headers
          expect(last_response).to be_a_deprecated_response
        end
      end
    end

    describe 'Removing a user from the organization' do
      let(:mgr) { User.make }
      let(:user) { User.make }
      let(:org) { Organization.make(manager_guids: [mgr.guid], user_guids: [user.guid]) }
      let(:org_space_empty) { Space.make(organization: org) }
      let(:org_space_full)  { Space.make(organization: org, manager_guids: [user.guid], developer_guids: [user.guid], auditor_guids: [user.guid]) }

      context 'DELETE /v2/organizations/org_guid/users/user_guid' do
        context 'without the recursive flag' do
          context 'a single organization' do
            it 'should remove the user from the organization if that user does not belong to any space' do
              org.add_space(org_space_empty)
              expect(org.users).to include(user)
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}", {}, admin_headers
              expect(last_response.status).to eql(204)

              org.refresh
              expect(org.user_guids).not_to include(user)
            end

            it 'should not remove the user from the organization if that user belongs to a space associated with the organization' do
              org.add_space(org_space_full)
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}", {}, admin_headers

              expect(last_response.status).to eql(400)
              org.refresh
              expect(org.users).to include(user)
            end
          end
        end

        context 'with recursive flag' do
          context 'a single organization' do
            it 'should remove the user from each space that is associated with the organization' do
              org.add_space(org_space_full)
              ['developers', 'auditors', 'managers'].each { |type| expect(org_space_full.send(type)).to include(user) }
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}?recursive=true", {}, admin_headers
              expect(last_response.status).to eql(204)

              org_space_full.refresh
              ['developers', 'auditors', 'managers'].each { |type| expect(org_space_full.send(type)).not_to include(user) }
            end

            it 'should remove the user from the organization' do
              org.add_space(org_space_full)
              expect(org.users).to include(user)
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}?recursive=true", {}, admin_headers
              expect(last_response.status).to eql(204)

              org.refresh
              expect(org.users).not_to include(user)
            end
          end

          context 'multiple organizations' do
            let(:org_2) { Organization.make(user_guids: [user.guid]) }
            let(:org2_space) { Space.make(organization: org_2, developer_guids: [user.guid]) }

            it 'should remove a user from one organization, but no the other' do
              org.add_space(org_space_full)
              org_2.add_space(org2_space)
              [org, org_2].each { |organization| expect(organization.users).to include(user) }
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}?recursive=true", {}, admin_headers
              expect(last_response.status).to eql(204)

              [org, org_2].each(&:refresh)
              expect(org.users).not_to include(user)
              expect(org_2.users).to include(user)
            end

            it 'should remove a user from each space associated with the organization being removed, but not the other' do
              org.add_space(org_space_full)
              org_2.add_space(org2_space)
              ['developers', 'auditors', 'managers'].each { |type| expect(org_space_full.send(type)).to include(user) }
              expect(org2_space.developers).to include(user)
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}?recursive=true", {}, admin_headers
              expect(last_response.status).to eql(204)

              [org_space_full, org2_space].each(&:refresh)
              ['developers', 'auditors', 'managers'].each { |type| expect(org_space_full.send(type)).not_to include(user) }
              expect(org2_space.developers).to include(user)
            end
          end
        end
      end

      context 'PUT /v2/organizations/org_guid' do
        it 'should remove the user if that user does not belong to any space associated with the organization' do
          org.add_space(org_space_empty)
          expect(org.users).to include(user)
          put "/v2/organizations/#{org.guid}", MultiJson.dump('user_guids' => []), admin_headers
          org.refresh
          expect(org.users).not_to include(user)
        end

        it 'should not remove the user if they attempt to delete the user through an update' do
          org.add_space(org_space_full)
          put "/v2/organizations/#{org.guid}", MultiJson.dump('user_guids' => []), admin_headers
          expect(last_response.status).to eql(400)
          org.refresh
          expect(org.users).to include(user)
        end
      end

      context 'PUT /v2/organizations/org_guid/private_domains/domain_guid' do
        context 'when PrivateDomain is shared' do
          let(:org1) { Organization.make }
          let(:org2) { Organization.make }
          let(:private_domain) { PrivateDomain.make(owning_organization: org1) }
          let(:user) { User.make }
          let(:manager) { User.make }
          let(:target_manager) { User.make }

          before do
            org1.add_manager(manager)
            org2.add_manager(manager)

            org1.add_auditor(target_manager)
            org2.add_manager(target_manager)
          end

          it 'should allow a user who is a manager of both the target org and the owning org to share a private domain' do
            put "/v2/organizations/#{org2.guid}/private_domains/#{private_domain.guid}", {}, headers_for(manager)
            expect(last_response.status).to eq(201)
            expect(org2.private_domains).to include(private_domain)
          end

          it 'should not allow the user to share domains to an org that the user is not a org manager of' do
            put "/v2/organizations/#{org2.guid}/private_domains/#{private_domain.guid}", {}, headers_for(user)
            expect(last_response.status).to eq(403)
          end

          it 'should not allow the user to share domains that user is not a manager in the owning organization of' do
            put "/v2/organizations/#{org2.guid}/private_domains/#{private_domain.guid}", {}, headers_for(target_manager)
            expect(last_response.status).to eq(403)
          end
        end
      end
    end

    describe 'GET /v2/organizations/:guid/users' do
      let(:mgr) { User.make }
      let(:user) { User.make }
      let(:org) { Organization.make(manager_guids: [mgr.guid], user_guids: [mgr.guid, user.guid]) }
      before do
        allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).and_return({})
      end

      it 'allows org managers' do
        get "/v2/organizations/#{org.guid}/users", '', headers_for(mgr)
        expect(last_response.status).to eq(200)
      end

      it 'allows org users' do
        get "/v2/organizations/#{org.guid}/users", '', headers_for(user)
        expect(last_response.status).to eq(200)
      end
    end

    describe 'when the default quota does not exist' do
      before do
        QuotaDefinition.default.organizations.each(&:destroy)
        QuotaDefinition.default.destroy
      end

      it 'returns an OrganizationInvalid message' do
        post '/v2/organizations', MultiJson.dump({ name: 'gotcha' }), admin_headers
        expect(last_response.status).to eql(400)
        expect(decoded_response['code']).to eq(30001)
        expect(decoded_response['description']).to include('Quota Definition could not be found')
      end
    end

    describe 'deleting an organization' do
      let(:org) { Organization.make }
      let(:user) { User.make }

      before do
        org.add_manager(user)
      end

      it 'deletes the org' do
        delete "/v2/organizations/#{org.guid}", '', admin_headers
        expect(last_response).to have_status_code 204
        expect { org.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      context 'with recursive=false' do
        before do
          Space.make(organization: org)
        end

        it 'raises an error when the org has anything in it' do
          delete "/v2/organizations/#{org.guid}", '', admin_headers
          expect(last_response).to have_status_code 400
          expect(decoded_response['error_code']).to eq 'CF-AssociationNotEmpty'
        end
      end

      context 'with recursive=true' do
        it 'deletes the org and all of its spaces' do
          space_1 = Space.make(organization: org)
          space_2 = Space.make(organization: org)

          delete "/v2/organizations/#{org.guid}?recursive=true", '', admin_headers
          expect(last_response).to have_status_code 204
          expect { org.refresh }.to raise_error Sequel::Error, 'Record not found'
          expect { space_1.refresh }.to raise_error Sequel::Error, 'Record not found'
          expect { space_2.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        context 'when one of the spaces has a v3 app in it' do
          let!(:space) { Space.make(organization: org) }
          let!(:app_model) { AppModel.make(space_guid: space.guid) }
          let(:user) { User.make }

          it 'deletes the v3 app' do
            delete "/v2/organizations/#{org.guid}?recursive=true", '', admin_headers
            expect(last_response).to have_status_code 204
            expect { app_model.refresh }.to raise_error Sequel::Error, 'Record not found'
          end

          it 'records an audit event that the app was deleted' do
            delete "/v2/organizations/#{org.guid}?recursive=true", '', admin_headers_for(user)
            expect(last_response).to have_status_code 204

            event = Event.find(type: 'audit.app.delete-request', actee: app_model.guid)
            expect(event).not_to be_nil
            expect(event.actor).to eq user.guid
          end
        end

        context 'when one of the spaces has a service instance in it' do
          before do
            stub_deprovision(service_instance, accepts_incomplete: true)
          end

          let!(:space) { Space.make(organization: org) }
          let!(:service_instance) { ManagedServiceInstance.make(space: space) }

          it 'deletes the service instance' do
            delete "/v2/organizations/#{org.guid}?recursive=true", '', admin_headers
            expect(last_response).to have_status_code 204
            expect { service_instance.refresh }.to raise_error Sequel::Error, 'Record not found'
          end

          context 'and one of the instances fails to delete' do
            let!(:service_instance_2) { ManagedServiceInstance.make(space: space) }
            let!(:service_instance_3) { ManagedServiceInstance.make(space: space) }
            let!(:service_binding) { ServiceBinding.make(service_instance: service_instance) }

            before do
              stub_deprovision(service_instance_2, status: 500, accepts_incomplete: true)
              stub_deprovision(service_instance_3, status: 200, accepts_incomplete: true)
              stub_unbind(service_binding)
            end

            it 'does not delete the org or the space' do
              delete "/v2/organizations/#{org.guid}?recursive=true", '', admin_headers
              expect(last_response).to have_status_code 502
              expect { org.refresh }.not_to raise_error
              expect { space.refresh }.not_to raise_error
            end

            it 'does not rollback deletion of other instances or bindings' do
              delete "/v2/organizations/#{org.guid}?recursive=true", '', admin_headers
              expect { service_instance.refresh }.to raise_error Sequel::Error, 'Record not found'
              expect { service_instance_3.refresh }.to raise_error Sequel::Error, 'Record not found'
              expect { service_binding.refresh }.to raise_error Sequel::Error, 'Record not found'
            end
          end
        end

        context 'and async=true' do
          let(:space) { Space.make(organization: org) }
          let(:service_instance) { ManagedServiceInstance.make(space: space) }

          before do
            stub_deprovision(service_instance, accepts_incomplete: true)
          end

          it 'successfully deletes the space in a background job' do
            space_guid = space.guid
            app_guid = AppModel.make(space_guid: space_guid).guid
            service_instance_guid = service_instance.guid
            route_guid = Route.make(space_guid: space_guid).guid

            delete "/v2/organizations/#{org.guid}?recursive=true&async=true", '', json_headers(admin_headers)

            expect(last_response).to have_status_code(202)
            expect(Organization.find(guid: org.guid)).not_to be_nil
            expect(Space.find(guid: space_guid)).not_to be_nil
            expect(AppModel.find(guid: app_guid)).not_to be_nil
            expect(ServiceInstance.find(guid: service_instance_guid)).not_to be_nil
            expect(Route.find(guid: route_guid)).not_to be_nil

            org_delete_jobs = Delayed::Job.where("handler like '%OrganizationDelete%'")
            expect(org_delete_jobs.count).to eq 1
            job = org_delete_jobs.first

            Delayed::Worker.new.work_off

            # a successfully completed job is removed from the table
            expect(Delayed::Job.find(id: job.id)).to be_nil

            expect(Organization.find(guid: org.guid)).to be_nil
            expect(Space.find(guid: space_guid)).to be_nil
            expect(AppModel.find(guid: app_guid)).to be_nil
            expect(ServiceInstance.find(guid: service_instance_guid)).to be_nil
            expect(Route.find(guid: route_guid)).to be_nil
          end

          context 'and the job times out' do
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

            it 'fails the job with a OrganizationDeleteTimeout error' do
              delete "/v2/organizations/#{org.guid}?recursive=true&async=true", '', json_headers(admin_headers)
              expect(last_response).to have_status_code(202)
              job_guid = decoded_response['metadata']['guid']

              expect(Delayed::Worker.new.work_off).to eq([0, 1])

              get "/v2/jobs/#{job_guid}", {}, json_headers(admin_headers)
              expect(decoded_response['entity']['status']).to eq 'failed'
              expect(decoded_response['entity']['error_details']['error_code']).to eq 'CF-OrganizationDeleteTimeout'
            end
          end

          context 'and a resource fails to delete' do
            before do
              stub_deprovision(service_instance, accepts_incomplete: true) do
                { status: 500, body: {}.to_json }
              end
            end

            it 'fails the job with a OrganizationDeleteTimeout error' do
              service_instance_error_string = ["#{service_instance.name}: The service broker returned an invalid",
                                               "response for the request to #{service_instance.dashboard_url}"].join(' ')

              delete "/v2/organizations/#{org.guid}?recursive=true&async=true", '', json_headers(admin_headers)
              expect(last_response).to have_status_code(202)
              job_guid = decoded_response['metadata']['guid']

              expect(Delayed::Worker.new.work_off).to eq([0, 1])

              get "/v2/jobs/#{job_guid}", {}, json_headers(admin_headers)
              expect(decoded_response['entity']['status']).to eq 'failed'
              expect(decoded_response['entity']['error_details']['error_code']).to eq 'CF-OrganizationDeletionFailed'
              expect(decoded_response['entity']['error_details']['description']).to include "Deletion of organization #{org.name}"
              expect(decoded_response['entity']['error_details']['description']).to include "Deletion of space #{space.name}"
              expect(decoded_response['entity']['error_details']['description']).to include service_instance_error_string
              expect(decoded_response['entity']['error_details']['description']).to include 'The service broker returned an invalid response for the request'
            end
          end
        end
      end

      context 'when the user is not an admin' do
        it 'raises an error' do
          delete "/v2/organizations/#{org.guid}", '', headers_for(user)
          expect(last_response).to have_status_code 403
        end
      end
    end

    describe 'DELETE /v2/organizations/:guid/private_domains/:domain_guid' do
      context 'when PrivateDomain is owned by the organization' do
        let(:organization) { Organization.make }
        let(:private_domain) { PrivateDomain.make(owning_organization: organization) }

        it 'fails' do
          delete "/v2/organizations/#{organization.guid}/private_domains/#{private_domain.guid}", {}, admin_headers
          expect(last_response.status).to eq(400)
        end
      end

      context 'when PrivateDomain is shared' do
        let(:space) { Space.make }
        let(:private_domain) { PrivateDomain.make }

        it 'removes associated routes' do
          private_domain = PrivateDomain.make

          space.organization.add_private_domain(private_domain)
          Route.make(space: space, domain: private_domain)

          delete "/v2/organizations/#{space.organization.guid}/private_domains/#{private_domain.guid}", {}, admin_headers
          expect(last_response.status).to eq(204)

          expect(private_domain.routes.count).to eq(0)
        end
      end
    end

    describe 'DELETE /v2/organizations/:guid/managers/:user_guid' do
      let(:org_manager) { User.make }

      before do
        org.add_manager org_manager
        org.save
      end

      describe 'removing the last org manager' do
        context 'as an admin' do
          it 'is allowed' do
            delete "/v2/organizations/#{org.guid}/managers/#{org_manager.guid}", {}, admin_headers
            expect(last_response.status).to eq(204)
          end
        end

        context 'as the manager' do
          it 'is not allowed' do
            delete "/v2/organizations/#{org.guid}/managers/#{org_manager.guid}", {}, headers_for(org_manager)
            expect(last_response.status).to eql(403)
            expect(decoded_response['code']).to eq(10003)
          end
        end
      end
    end

    describe 'adding user roles by username' do
      [:user, :manager, :billing_manager, :auditor].each do |role|
        plural_role = role.to_s.pluralize
        describe "PUT /v2/organizations/:guid/#{plural_role}" do
          let(:user) { User.make(username: 'larry_the_user') }

          before do
            allow_any_instance_of(UaaClient).to receive(:id_for_username).with(user.username).and_return(user.guid)
          end

          it "makes the user an org #{role}" do
            put "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(201)
            expect(org.send(plural_role)).to include(user)
            expect(decoded_response['metadata']['guid']).to eq(org.guid)
          end

          it "makes the user an org #{role}, and creates a user record when one does not exist" do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).with('uaa-only-user@example.com').and_return('user-guid')
            put "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: 'uaa-only-user@example.com' }), admin_headers

            expect(last_response.status).to eq(201)
            expect(org.send("#{plural_role}_dataset").where(guid: 'user-guid')).to_not be_empty
          end

          it 'verifies the user has update access to the org' do
            expect_any_instance_of(OrganizationsController).to receive(:find_guid_and_validate_access).with(:update, org.guid).and_call_original
            put "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers
          end

          it 'returns a 404 when the user does not exist in UAA' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).with('fake@example.com').and_return(nil)

            put "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: 'fake@example.com' }), admin_headers

            expect(last_response.status).to eq(404)
            expect(decoded_response['code']).to eq(20003)
          end

          it 'returns an error when UAA is not available' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaUnavailable)

            put "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(503)
            expect(decoded_response['code']).to eq(20004)
          end

          it 'returns an error when UAA endpoint is disabled' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaEndpointDisabled)

            put "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(501)
            expect(decoded_response['code']).to eq(20005)
          end

          context 'when the feature flag "set_roles_by_username" is disabled' do
            before do
              FeatureFlag.new(name: 'set_roles_by_username', enabled: false).save
            end

            it 'raises a feature flag error for non-admins' do
              put "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), headers_for(user)

              expect(last_response.status).to eq(403)
              expect(decoded_response['code']).to eq(330002)
            end

            it 'succeeds for admins' do
              put "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

              expect(last_response.status).to eq(201)
              expect(org.send(plural_role)).to include(user)
              expect(decoded_response['metadata']['guid']).to eq(org.guid)
            end
          end
        end
      end
    end

    describe 'removing user roles by username' do
      [:user, :manager, :billing_manager, :auditor].each do |role|
        plural_role = role.to_s.pluralize
        describe "DELETE /v2/organizations/:guid/#{plural_role}" do
          let(:user) { User.make(username: 'larry_the_user') }

          before do
            allow_any_instance_of(UaaClient).to receive(:id_for_username).with(user.username).and_return(user.guid)
            org.send("add_#{role}", user)
          end

          it "unsets the user as an org #{role}" do
            expect(org.send(plural_role)).to include(user)

            delete "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(200)
            expect(org.reload.send(plural_role)).to_not include(user)
            expect(decoded_response['metadata']['guid']).to eq(org.guid)
          end

          it 'verifies the user has update access to the org' do
            expect_any_instance_of(OrganizationsController).to receive(:find_guid_and_validate_access).with(:update, org.guid).and_call_original
            delete "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers
          end

          it 'returns a 404 when the user does not exist in CC' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).with('fake@example.com').and_return('not-a-guid')

            delete "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: 'fake@example.com' }), admin_headers

            expect(last_response.status).to eq(404)
            expect(decoded_response['code']).to eq(20003)
          end

          it 'returns an error when UAA is not available' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaUnavailable)

            delete "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(503)
            expect(decoded_response['code']).to eq(20004)
          end

          it 'returns an error when UAA endpoint is disabled' do
            expect_any_instance_of(UaaClient).to receive(:id_for_username).and_raise(UaaEndpointDisabled)

            delete "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

            expect(last_response.status).to eq(501)
            expect(decoded_response['code']).to eq(20005)
          end

          context 'when the feature flag "set_roles_by_username" is disabled' do
            before do
              FeatureFlag.new(name: 'unset_roles_by_username', enabled: false).save
            end

            it 'raises a feature flag error for non-admins' do
              delete "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), headers_for(user)

              expect(last_response.status).to eq(403)
              expect(decoded_response['code']).to eq(330002)
            end

            it 'succeeds for admins' do
              expect(org.send(plural_role)).to include(user)
              delete "/v2/organizations/#{org.guid}/#{plural_role}", MultiJson.dump({ username: user.username }), admin_headers

              expect(last_response.status).to eq(200)
              expect(org.reload.send(plural_role)).to_not include(user)
              expect(decoded_response['metadata']['guid']).to eq(org.guid)
            end
          end
        end
      end
    end
  end
end
