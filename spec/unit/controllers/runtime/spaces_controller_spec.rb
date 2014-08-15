require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::SpacesController do
    let(:organization_one) { Organization.make }
    let(:space_one) { Space.make(organization: organization_one) }

    describe "Query Parameters" do
      it { expect(described_class).to be_queryable_by(:name) }
      it { expect(described_class).to be_queryable_by(:organization_guid) }
      it { expect(described_class).to be_queryable_by(:developer_guid) }
      it { expect(described_class).to be_queryable_by(:app_guid) }
    end

    describe "Attributes" do
      it do
        expect(described_class).to have_creatable_attributes({
          name:                   { type: "string", required: true },
          organization_guid:      { type: "string", required: true },
          developer_guids:        { type: "[string]" },
          manager_guids:          { type: "[string]" },
          auditor_guids:          { type: "[string]" },
          app_guids:              { type: "[string]" },
          route_guids:            { type: "[string]" },
          domain_guids:           { type: "[string]" },
          service_instance_guids: { type: "[string]" },
          app_event_guids:        { type: "[string]" },
          event_guids:            { type: "[string]" },
          security_group_guids:   { type: "[string]" }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name:                   { type: "string" },
          organization_guid:      { type: "string" },
          developer_guids:        { type: "[string]" },
          manager_guids:          { type: "[string]" },
          auditor_guids:          { type: "[string]" },
          app_guids:              { type: "[string]" },
          route_guids:            { type: "[string]" },
          domain_guids:           { type: "[string]" },
          service_instance_guids: { type: "[string]" },
          app_event_guids:        { type: "[string]" },
          event_guids:            { type: "[string]" },
          security_group_guids:   { type: "[string]" }
        })
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = @space_a
        @obj_b = @space_b
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission enumeration", "OrgManager",
            :name => 'space',
            :path => "/v2/spaces",
            :enumerate => 1
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission enumeration", "OrgUser",
            :name => 'space',
            :path => "/v2/spaces",
            :enumerate => 0
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission enumeration", "BillingManager",
            :name => 'space',
            :path => "/v2/spaces",
            :enumerate => 0
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission enumeration", "Auditor",
            :name => 'space',
            :path => "/v2/spaces",
            :enumerate => 0
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "permission enumeration", "SpaceManager",
            :name => 'space',
            :path => "/v2/spaces",
            :enumerate => 1
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission enumeration", "Developer",
            :name => 'space',
            :path => "/v2/spaces",
            :enumerate => 1
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission enumeration", "SpaceAuditor",
            :name => 'space',
            :path => "/v2/spaces",
            :enumerate => 1
        end
      end
    end

    describe 'GET /v2/spaces/:guid/service_instances' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }

      context 'when filtering results' do
        it 'returns only matching results' do
          user_provided_service_instance_1 = UserProvidedServiceInstance.make(space: space, name: 'provided service 1')
          user_provided_service_instance_2 = UserProvidedServiceInstance.make(space: space, name: 'provided service 2')
          managed_service_instance_1 = ManagedServiceInstance.make(space: space, name: 'managed service 1')
          managed_service_instance_2 = ManagedServiceInstance.make(space: space, name: 'managed service 2')

          get "v2/spaces/#{space.guid}/service_instances", {'q' => 'name:provided service 1;', 'return_user_provided_service_instances' => true}, headers_for(developer)
          guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
          expect(guids).to eq([user_provided_service_instance_1.guid])

          get "v2/spaces/#{space.guid}/service_instances", {'q' => 'name:managed service 1;', 'return_user_provided_service_instances' => true}, headers_for(developer)
          guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
          expect(guids).to eq([managed_service_instance_1.guid])
        end
      end

      context 'when there are provided service instances' do
        let!(:user_provided_service_instance) { UserProvidedServiceInstance.make(space: space) }
        let!(:managed_service_instance) { ManagedServiceInstance.make(space: space) }

        describe 'when return_user_provided_service_instances is true' do
          it 'returns ManagedServiceInstances and UserProvidedServiceInstances' do
            get "v2/spaces/#{space.guid}/service_instances", {return_user_provided_service_instances: true}, headers_for(developer)

            guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
            expect(guids).to include(user_provided_service_instance.guid, managed_service_instance.guid)
          end

          it 'includes service_plan_url for managed service instances' do
            get "/v2/spaces/#{space.guid}/service_instances", {return_user_provided_service_instances: true}, headers_for(developer)
            service_instances_response = decoded_response.fetch('resources')
            managed_service_instance_response = service_instances_response.detect {|si|
              si.fetch('metadata').fetch('guid') == managed_service_instance.guid
            }
            expect(managed_service_instance_response.fetch('entity').fetch('service_plan_url')).to be
            expect(managed_service_instance_response.fetch('entity').fetch('space_url')).to be
            expect(managed_service_instance_response.fetch('entity').fetch('service_bindings_url')).to be
          end

          it 'includes the correct service binding url' do
            get "/v2/spaces/#{space.guid}/service_instances", {return_user_provided_service_instances: true}, headers_for(developer)
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
        include_context "permissions"
        shared_examples "disallow enumerating service instances" do |perm_name|
          describe "disallowing enumerating service instances" do
            it "disallows a user that only has #{perm_name} permission on the space" do
              get "/v2/spaces/#{@space_a.guid}/service_instances", {}, headers_for(member_a)

              expect(last_response.status).to eq(403)
            end
          end
        end

        shared_examples "enumerating service instances" do |perm_name, opts|
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
            expect(decoded_response["total_results"]).to eq(expected)
            guids = decoded_response["resources"].map { |o| o["metadata"]["guid"] }
            expect(guids).to include(managed_service_instance.guid) if expected > 0
          end

          it "should not return a service instance to a user with the #{perm_name} permission on a different space" do
            get path, {}, headers_for(member_b)
            expect(last_response.status).to eq(403)
          end
        end

        shared_examples "disallow enumerating services" do |perm_name|
          describe "disallowing enumerating services" do
            it "disallows a user that only has #{perm_name} permission on the space" do
              get "/v2/spaces/#{@space_a.guid}/services", {}, headers_for(member_a)

              expect(last_response).to be_forbidden
            end
          end
        end

        shared_examples "enumerating services" do |perm_name, opts|
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

        describe "Org Level" do
          describe "OrgManager" do
            it_behaves_like(
              "enumerating service instances", "OrgManager",
              expected: 0,
            ) do
              let(:member_a) { @org_a_manager }
              let(:member_b) { @org_b_manager }
            end

            it_behaves_like(
              "enumerating services", "OrgManager",
            ) do
              let(:member_a) { @org_a_manager }
              let(:member_b) { @org_b_manager }
            end
          end

          describe "OrgUser" do
            it_behaves_like(
              "disallow enumerating service instances", "OrgUser",
            ) do
              let(:member_a) { @org_a_member }
            end

            it_behaves_like(
              "disallow enumerating services", "OrgUser",
            ) do
              let(:member_a) { @org_a_member }
            end
          end

          describe "BillingManager" do
            it_behaves_like(
              "disallow enumerating service instances", "BillingManager",
            ) do
              let(:member_a) { @org_a_billing_manager }
            end

            it_behaves_like(
              "disallow enumerating services", "BillingManager",
            ) do
              let(:member_a) { @org_a_billing_manager }
            end
          end

          describe "Auditor" do
            it_behaves_like(
              "disallow enumerating service instances", "Auditor",
            ) do
              let(:member_a) { @org_a_auditor }
            end

            it_behaves_like(
              "disallow enumerating services", "Auditor",
            ) do
              let(:member_a) { @org_a_auditor }
            end
          end
        end

        describe "App Space Level Permissions" do
          describe "SpaceManager" do
            it_behaves_like(
              "enumerating service instances", "SpaceManager",
              expected: 0,
            ) do
              let(:member_a) { @space_a_manager }
              let(:member_b) { @space_b_manager }
            end

            it_behaves_like(
              "enumerating services", "SpaceManager",
            ) do
              let(:member_a) { @space_a_manager }
              let(:member_b) { @space_b_manager }
            end
          end

          describe "Developer" do
            it_behaves_like(
              "enumerating service instances", "Developer",
              expected: 1,
            ) do
              let(:member_a) { @space_a_developer }
              let(:member_b) { @space_b_developer }
            end

            it_behaves_like(
              "enumerating services", "Developer",
            ) do
              let(:member_a) { @space_a_developer }
              let(:member_b) { @space_b_developer }
            end
          end

          describe "SpaceAuditor" do
            it_behaves_like(
              "enumerating service instances", "SpaceAuditor",
              expected: 1,
            ) do
              let(:member_a) { @space_a_auditor }
              let(:member_b) { @space_b_auditor }
            end

            it_behaves_like(
              "enumerating services", "SpaceAuditor",
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
      let(:space_two) { Space.make(organization: organization_two)}
      let(:user) { make_developer_for_space(space_one) }
      let (:headers) do
        headers_for(user)
      end

      before do
        user.add_organization(organization_two)
        space_two.add_developer(user)
      end

      def decoded_guids
        decoded_response['resources'].map { |r| r['metadata']['guid'] }
      end

      context 'with an offering that has private plans' do
        before(:each) do
          @service = Service.make(:active => true)
          @service_plan = ServicePlan.make(:service => @service, public: false)
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
          @active = 3.times.map { Service.make(:active => true).tap{|svc| ServicePlan.make(:service => svc) } }
          @inactive = 2.times.map { Service.make(:active => false).tap{|svc| ServicePlan.make(:service => svc) } }
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

    describe "audit events" do
      let(:organization) { Organization.make }

      it "logs audit.space.create when creating a space" do
        request_body = {organization_guid: organization.guid, name: "space_name"}.to_json
        post "/v2/spaces", request_body, json_headers(admin_headers)

        expect(last_response.status).to eq(201)

        new_space_guid = decoded_response['metadata']['guid']
        event = Event.find(:type => "audit.space.create", :actee => new_space_guid)
        expect(event).not_to be_nil
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
        expect(event.metadata["request"]).to eq("organization_guid" => organization.guid, "name" => "space_name")
      end

      it "logs audit.space.update when updating a space" do
        space = Space.make
        request_body = {name: "new_space_name"}.to_json
        put "/v2/spaces/#{space.guid}", request_body, json_headers(admin_headers)

        expect(last_response.status).to eq(201)

        space_guid = decoded_response['metadata']['guid']
        event = Event.find(:type => "audit.space.update", :actee => space_guid)
        expect(event).not_to be_nil
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
        expect(event.metadata["request"]).to eq("name" => "new_space_name")
      end

      it "logs audit.space.delete-request when deleting a space" do
        space = Space.make
        organization_guid = space.organization.guid
        space_guid = space.guid
        delete "/v2/spaces/#{space_guid}", "", json_headers(admin_headers)

        expect(last_response.status).to eq(204)

        event = Event.find(:type => "audit.space.delete-request", :actee => space_guid)
        expect(event).not_to be_nil
        expect(event.metadata["request"]).to eq("recursive" => false)
        expect(event.space_guid).to eq(space_guid)
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
        expect(event.organization_guid).to eq(organization_guid)
      end
    end

    describe "app_events associations" do
      it "does not return app_events with inline-relations-depth=0" do
        space = Space.make
        get "/v2/spaces/#{space.guid}?inline-relations-depth=0", {}, json_headers(admin_headers)
        expect(entity).to have_key("app_events_url")
        expect(entity).to_not have_key("app_events")
      end

      it "does not return app_events with inline-relations-depth=1 since app_events dataset is relatively expensive to query" do
        space = Space.make
        get "/v2/spaces/#{space.guid}?inline-relations-depth=1", {}, json_headers(admin_headers)
        expect(entity).to have_key("app_events_url")
        expect(entity).to_not have_key("app_events")
      end
    end

    describe "events associations" do
      it "does not return events with inline-relations-depth=0" do
        space = Space.make
        get "/v2/spaces/#{space.guid}?inline-relations-depth=0", {}, json_headers(admin_headers)
        expect(entity).to have_key("events_url")
        expect(entity).to_not have_key("events")
      end

      it "does not return events with inline-relations-depth=1 since events dataset is relatively expensive to query" do
        space = Space.make
        get "/v2/spaces/#{space.guid}?inline-relations-depth=1", {}, json_headers(admin_headers)
        expect(entity).to have_key("events_url")
        expect(entity).to_not have_key("events")
      end
    end

    describe "Deprecated endpoints" do
      let!(:domain) { SharedDomain.make }
      describe "DELETE /v2/spaces/:guid/domains/:shared_domain" do
        it "should pretends that it deleted a domain" do
          delete "/v2/spaces/#{space_one.guid}/domains/#{domain.guid}"
          expect(last_response).to be_a_deprecated_response
        end
      end

      describe "GET /v2/organizations/:guid/domains/:guid" do
        it "should be deprecated" do
          get "/v2/spaces/#{space_one.guid}/domains/#{domain.guid}"
          expect(last_response).to be_a_deprecated_response
        end
      end
    end
  end
end
