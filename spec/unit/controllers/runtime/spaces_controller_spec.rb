require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::SpacesController do
    it_behaves_like "an authenticated endpoint", path: "/v2/spaces"
    include_examples "querying objects", path: "/v2/spaces", model: Space, queryable_attributes: %w(name)
    include_examples "enumerating objects", path: "/v2/spaces", model: Space
    include_examples "reading a valid object", path: "/v2/spaces", model: Space, basic_attributes: %w(name organization_guid)
    include_examples "operations on an invalid object", path: "/v2/spaces"
    include_examples "creating and updating", path: "/v2/spaces", model: Space, required_attributes: %w(name organization_guid), unique_attributes: %w(name organization_guid)
    include_examples "deleting a valid object", path: "/v2/spaces", model: Space,
      one_to_many_collection_ids: {
        apps: lambda { |space| AppFactory.make(:space => space) },
        service_instances: lambda { |space| ManagedServiceInstance.make(:space => space) },
        routes: lambda { |space| Route.make(:space => space) },
        default_users: lambda { |space|
          user = VCAP::CloudController::User.make
          space.organization.add_user(user)
          space.add_developer(user)
          space.save
          user.default_space = space
          user.save
          user
        }
      }, excluded: [:default_users]
    include_examples "collection operations", path: "/v2/spaces", model: Space,
      one_to_many_collection_ids: {
        apps: lambda { |space| AppFactory.make(space: space) },
        routes: lambda { |space| Route.make(space: space) },
        service_instances: lambda { |space| ManagedServiceInstance.make(space: space) }
      },
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {
        developers:          lambda { |space| make_user_for_space(space) },
        managers:            lambda { |space| make_user_for_space(space) },
        auditors:            lambda { |space| make_user_for_space(space) },
        app_security_groups: lambda { |space| AppSecurityGroup.make }
      }


    describe "data integrity" do
      let(:space) { Space.make }

      it "should not make strings into integers" do
        space.name = "1234"
        space.save
        get "/v2/spaces/#{space.guid}", {}, admin_headers
        decoded_response["entity"]["name"].should == "1234"
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = @space_a
        @obj_b = @space_b
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name, :organization_guid => @org_a.guid)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name)
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

    describe 'GET /v2/spaces/:guid/domains' do
      let(:space) { Space.make }
      let(:manager) { make_manager_for_org(space.organization) }

      before do
        @private_domain = PrivateDomain.make(owning_organization: space.organization)
        @shared_domain = SharedDomain.make
      end

      it "should return the domains associated with the owning organization for allowed users" do
        get "/v2/spaces/#{space.guid}/domains", {}, headers_for(manager)
        expect(last_response.status).to eq(200)
        resources = decoded_response.fetch("resources")
        expect(resources).to have(2).items

        guids = resources.map { |x| x["metadata"]["guid"] }
        expect(guids).to match_array([@shared_domain.guid, @private_domain.guid])
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
          guids.should == [user_provided_service_instance_1.guid]

          get "v2/spaces/#{space.guid}/service_instances", {'q' => 'name:managed service 1;', 'return_user_provided_service_instances' => true}, headers_for(developer)
          guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
          guids.should == [managed_service_instance_1.guid]
        end
      end

      context 'when there are provided service instances' do
        let!(:user_provided_service_instance) { UserProvidedServiceInstance.make(space: space) }
        let!(:managed_service_instance) { ManagedServiceInstance.make(space: space) }

        describe 'when return_user_provided_service_instances is true' do
          it 'returns ManagedServiceInstances and UserProvidedServiceInstances' do
            get "v2/spaces/#{space.guid}/service_instances", {return_user_provided_service_instances: true}, headers_for(developer)

            guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
            guids.should include(user_provided_service_instance.guid, managed_service_instance.guid)
          end

          it 'includes service_plan_url for managed service instances' do
            get "/v2/spaces/#{space.guid}/service_instances", {return_user_provided_service_instances: true}, headers_for(developer)
            service_instances_response = decoded_response.fetch('resources')
            managed_service_instance_response = service_instances_response.detect {|si|
              si.fetch('metadata').fetch('guid') == managed_service_instance.guid
            }
            managed_service_instance_response.fetch('entity').fetch('service_plan_url').should be
            managed_service_instance_response.fetch('entity').fetch('space_url').should be
            managed_service_instance_response.fetch('entity').fetch('service_bindings_url').should be
          end
        end

        describe 'when return_user_provided_service_instances flag is not present' do
          it 'returns only the managed service instances' do
            get "/v2/spaces/#{space.guid}/service_instances", '', headers_for(developer)
            guids = decoded_response.fetch('resources').map { |service| service.fetch('metadata').fetch('guid') }
            guids.should =~ [managed_service_instance.guid]
          end

          it 'includes service_plan_url for managed service instances' do
            get "/v2/spaces/#{space.guid}/service_instances", '', headers_for(developer)
            service_instances_response = decoded_response.fetch('resources')
            managed_service_instance_response = service_instances_response.detect {|si|
              si.fetch('metadata').fetch('guid') == managed_service_instance.guid
            }
            managed_service_instance_response.fetch('entity').fetch('service_plan_url').should be
            managed_service_instance_response.fetch('entity').fetch('space_url').should be
            managed_service_instance_response.fetch('entity').fetch('service_bindings_url').should be
          end
        end
      end

      describe 'Permissions' do
        include_context "permissions"
        shared_examples "disallow enumerating service instances" do |perm_name|
          describe "disallowing enumerating service instances" do
            it "disallows a user that only has #{perm_name} permission on the space" do
              get "/v2/spaces/#{@space_a.guid}/service_instances", {}, headers_for(member_a)

              last_response.status.should == 403
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

            last_response.should be_ok
            decoded_response["total_results"].should == expected
            guids = decoded_response["resources"].map { |o| o["metadata"]["guid"] }
            guids.should include(managed_service_instance.guid) if expected > 0
          end

          it "should not return a service instance to a user with the #{perm_name} permission on a different space" do
            get path, {}, headers_for(member_b)
            last_response.status.should eq(403)
          end
        end

        shared_examples "disallow enumerating services" do |perm_name|
          describe "disallowing enumerating services" do
            it "disallows a user that only has #{perm_name} permission on the space" do
              get "/v2/spaces/#{@space_a.guid}/services", {}, headers_for(member_a)

              last_response.should be_forbidden
            end
          end
        end

        shared_examples "enumerating services" do |perm_name, opts|
          let(:path) { "/v2/spaces/#{@space_a.guid}/services" }

          it "should return services to a user that has #{perm_name} permissions" do
            get path, {}, headers_for(member_a)

            last_response.should be_ok
          end

          it "should not return services to a user with the #{perm_name} permission on a different space" do
            get path, {}, headers_for(member_b)
            last_response.should be_forbidden
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

    let(:organization_one) { Organization.make }
    let(:space_one) { Space.make(organization: organization_one) }

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
          last_response.should be_ok
          decoded_guids.should_not include(@service.guid)
        end

        it "should return the offering when the org has access to one of the service's plans" do
          get "/v2/spaces/#{space_one.guid}/services", {}, headers
          last_response.should be_ok
          decoded_guids.should include(@service.guid)
        end

        it 'should include plans that are visible to the org' do
          get "/v2/spaces/#{space_one.guid}/services?inline-relations-depth=1", {}, headers

          last_response.should be_ok
          service = decoded_response.fetch('resources').fetch(0)
          service_plans = service.fetch('entity').fetch('service_plans')
          service_plans.length.should == 1
          service_plans.first.fetch('metadata').fetch('guid').should == @service_plan.guid
          service_plans.first.fetch('metadata').fetch('url').should == "/v2/service_plans/#{@service_plan.guid}"
        end

        it 'should exclude plans that are not visible to the org' do
          public_service_plan = ServicePlan.make(service: @service, public: true)

          get "/v2/spaces/#{space_two.guid}/services?inline-relations-depth=1", {}, headers

          last_response.should be_ok
          service = decoded_response.fetch('resources').fetch(0)
          service_plans = service.fetch('entity').fetch('service_plans')
          service_plans.length.should == 1
          service_plans.first.fetch('metadata').fetch('guid').should == public_service_plan.guid
        end
      end

      describe 'get /v2/spaces/:guid/services?q=active:<t|f>' do
        before(:each) do
          @active = 3.times.map { Service.make(:active => true).tap{|svc| ServicePlan.make(:service => svc) } }
          @inactive = 2.times.map { Service.make(:active => false).tap{|svc| ServicePlan.make(:service => svc) } }
        end

        it 'can remove inactive services' do
          # Sequel stores 'true' and 'false' as 't' and 'f' in sqlite, so with
          # sqlite, instead of 'true' or 'false', the parameter must be specified
          # as 't' or 'f'. But in postgresql, either way is ok.
          get "/v2/spaces/#{space_one.guid}/services?q=active:t", {}, headers
          last_response.should be_ok
          decoded_guids.should =~ @active.map(&:guid)
        end

        it 'can only get inactive services' do
          get "/v2/spaces/#{space_one.guid}/services?q=active:f", {}, headers
          last_response.should be_ok
          decoded_guids.should =~ @inactive.map(&:guid)
        end
      end
    end

    describe "audit events" do
      let(:organization) { Organization.make }
      describe "audit.space.create" do
        it "is logged when creating a space" do
          request_body = {organization_guid: organization.guid, name: "space_name"}.to_json
          post "/v2/spaces", request_body, json_headers(admin_headers)

          last_response.status.should == 201

          new_space_guid = decoded_response['metadata']['guid']
          event = Event.find(:type => "audit.space.create", :actee => new_space_guid)
          expect(event).not_to be_nil
          expect(event.actor_name).to eq(SecurityContext.current_user_email)
          expect(event.metadata["request"]).to eq("organization_guid" => organization.guid, "name" => "space_name")
        end
      end

      it "logs audit.space.update when updating a space" do
        space = Space.make
        request_body = {name: "new_space_name"}.to_json
        put "/v2/spaces/#{space.guid}", request_body, json_headers(admin_headers)

        last_response.status.should == 201

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

        last_response.status.should == 204

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

    describe 'GET', '/v2/spaces?inline-relations-depth=3', regression: true do
      let(:space) { Space.make }

      it 'returns managed service instances associated with service plans' do
        managed_service_instance = ManagedServiceInstance.make(space: space)
        ServiceBinding.make(service_instance: managed_service_instance)

        get "/v2/spaces/#{space.guid}?inline-relations-depth=3", {}, admin_headers
        expect(last_response.status).to eql(200)
        service_instance_hashes = decoded_response["entity"]["service_instances"]

        managed_service_instance_hash =
          find_service_instance_with_guid(service_instance_hashes, managed_service_instance.guid)
        expect(managed_service_instance_hash["entity"]["service_plan_url"]).to be
        expect(managed_service_instance_hash["entity"]["service_plan_guid"]).to be
        expect(managed_service_instance_hash["entity"]["service_plan"]).to be
      end

      it 'returns provided service instances without plans' do
        user_provided_service_instance = UserProvidedServiceInstance.make(space: space)
        ServiceBinding.make(service_instance: user_provided_service_instance)

        get "/v2/spaces/#{space.guid}?inline-relations-depth=3", {}, admin_headers
        expect(last_response.status).to eql(200)
        service_instance_hashes = decoded_response["entity"]["service_instances"]

        user_provided_service_instance_hash =
          find_service_instance_with_guid(service_instance_hashes, user_provided_service_instance.guid)
        expect(user_provided_service_instance_hash["entity"]).to_not have_key("service_plan_url")
        expect(user_provided_service_instance_hash["entity"]).to_not have_key("service_plan_guid")
        expect(user_provided_service_instance_hash["entity"]).to_not have_key("service_plan")
      end

      def find_service_instance_with_guid(service_instances, guid)
        service_instances.detect { |res| res["metadata"]["guid"] == guid } ||
          raise("Failed to find service instance with #{guid}")
      end
    end
  end
end
