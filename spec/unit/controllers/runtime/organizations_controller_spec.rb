require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::OrganizationsController do
    let(:org) { Organization.make }
    it_behaves_like "an authenticated endpoint", path: "/v2/organizations"
    include_examples "querying objects", path: "/v2/organizations", model: Organization, queryable_attributes: %w(name status)
    include_examples "enumerating objects", path: "/v2/organizations", model: Organization
    include_examples "reading a valid object", path: "/v2/organizations", model: Organization, basic_attributes: %w(name)
    include_examples "operations on an invalid object", path: "/v2/organizations"
    include_examples "creating and updating", path: "/v2/organizations", model: Organization, required_attributes: %w(name), unique_attributes: %w(name)
    include_examples "deleting a valid object", path: "/v2/organizations", model: Organization,
    one_to_many_collection_ids: {
      :spaces => lambda { |org| Space.make(:organization => org) },
      :service_instances => lambda { |org|
        space = Space.make(:organization => org)
        ManagedServiceInstance.make(:space => space)
      },
      :apps => lambda { |org|
        space = Space.make(:organization => org)
        AppFactory.make(:space => space)
      },
      :private_domains => lambda { |org|
        PrivateDomain.make(:owning_organization => org)
      }
    }
    include_examples "collection operations", path: "/v2/organizations", model: Organization,
    one_to_many_collection_ids: {
      spaces: lambda { |org| Space.make(organization: org) },
      private_domains: lambda { |org| PrivateDomain.make(owning_organization: org) },
    },
      many_to_one_collection_ids: {},
    many_to_many_collection_ids: {
      users: lambda { |org| User.make },
      billing_managers: lambda { |org| User.make }
    }

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = @org_a
        @obj_b = @org_b
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name)
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission enumeration", "OrgManager",
            :name => 'organization',
            :path => "/v2/organizations",
            :enumerate => 1
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission enumeration", "OrgUser",
            :name => 'organization',
            :path => "/v2/organizations",
            :enumerate => 1
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission enumeration", "BillingManager",
            :name => 'organization',
            :path => "/v2/organizations",
            :enumerate => 1
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission enumeration", "Auditor",
            :name => 'organization',
            :path => "/v2/organizations",
            :enumerate => 1
        end
      end
    end

    describe "billing" do
      let(:org_admin_headers) do
        user = User.make
        org.add_user(user)
        org.add_manager(user)
        headers_for(user)
      end

      it "should export the billing_enabled flag" do
        org.billing_enabled = true
        org.save(:validate => false)
        get "/v2/organizations/#{org.guid}", {}, admin_headers
        last_response.status.should == 200
        decoded_response["entity"]["billing_enabled"].should == true
      end

      describe "cf admins" do
        it "should be allowed to set billing_enabled flag to true" do
          org.billing_enabled.should == false
          req = Yajl::Encoder.encode(:billing_enabled => true)
          put "/v2/organizations/#{org.guid}", req, json_headers(admin_headers)
          last_response.status.should == 201
          decoded_response["entity"]["billing_enabled"].should == true
          org.refresh
          org.billing_enabled.should == true
        end
      end

      describe "org admins" do
        it "should not be allowed to set billing_enabled flag to true" do
          org.billing_enabled.should == false
          req = Yajl::Encoder.encode(:billing_enabled => true)
          put "/v2/organizations/#{org.guid}", req, json_headers(org_admin_headers)

          last_response.status.should == 400
          org.refresh
          org.billing_enabled.should == false
        end

        it "should not be allowed to set billing_enabled flag to false" do
          org.billing_enabled = true
          org.save(:validate => false)
          req = Yajl::Encoder.encode(:billing_enabled => false)
          put "/v2/organizations/#{org.guid}", req, json_headers(org_admin_headers)
          last_response.status.should == 400
          org.refresh
          org.billing_enabled.should == true
        end
      end
    end

    describe 'GET /v2/organizations/:guid/domains' do
      let(:organization) { Organization.make }
      let(:manager) { make_manager_for_org(organization) }

      before do
        @private_domain = PrivateDomain.make(owning_organization: organization)
        @shared_domain = SharedDomain.make
      end

      it "should return the private domains associated with the organization and all shared domains" do
        get "/v2/organizations/#{organization.guid}/domains", {}, headers_for(manager)
        expect(last_response.status).to eq(200)
        resources = decoded_response.fetch("resources")
        expect(resources).to have(2).items
        guids = resources.map { |x| x["metadata"]["guid"] }
        expect(guids).to match_array([@shared_domain.guid, @private_domain.guid])
      end

      context "space roles" do
        let(:organization) { Organization.make }
        let(:space) { Space.make(organization: organization) }

        context "space developers without org role" do
          let(:space_developer) do
            make_developer_for_space(space)
          end

          it "returns private domains" do
            private_domain = PrivateDomain.make(owning_organization: organization)
            get "/v2/organizations/#{organization.guid}/domains", {}, headers_for(space_developer)
            expect(last_response.status).to eq(200)
            guids = decoded_response.fetch("resources").map { |x| x["metadata"]["guid"] }
            expect(guids).to include(private_domain.guid)
          end
        end
      end
    end

    describe "quota definition" do
      let(:org_admin_headers) do
        user = User.make
        org.add_user(user)
        org.add_manager(user)
        headers_for(user)
      end

      let(:quota_definition) do
        QuotaDefinition.make
      end

      let(:update_request) do
        Yajl::Encoder.encode(:quota_definition_guid => quota_definition.guid)
      end

      describe "cf admins" do
        it "should be allowed to set the quota definition" do
          put "/v2/organizations/#{org.guid}", update_request, json_headers(admin_headers)
          last_response.status.should == 201
          org.refresh
          org.quota_definition.should == quota_definition
        end
      end

      describe "org admins" do
        it "should not be allowed to set the quota definition" do
          orig_quota_definition = org.quota_definition
          put "/v2/organizations/#{org.guid}", update_request, json_headers(org_admin_headers)
          last_response.status.should == 403
          org.refresh
          org.quota_definition.should == orig_quota_definition
        end
      end
    end

    describe "app_events associations" do
      it "does not return app_events with inline-relations-depth=0" do
        org = Organization.make
        get "/v2/organizations/#{org.guid}?inline-relations-depth=0", {}, json_headers(admin_headers)
        expect(last_response.status).to eq 200
        expect(entity).to have_key("app_events_url")
        expect(entity).to_not have_key("app_events")
      end

      it "does not return app_events with inline-relations-depth=1 since app_events dataset is relatively expensive to query" do
        org = Organization.make
        get "/v2/organizations/#{org.guid}?inline-relations-depth=1", {}, json_headers(admin_headers)
        expect(entity).to have_key("app_events_url")
        expect(entity).to_not have_key("app_events")
      end
    end

    describe "Deprecated endpoints" do
      let!(:domain) { SharedDomain.make }
      describe "DELETE /v2/organizations/:guid/domains/:shared_domain_guid" do
        it "should pretends that it deleted a domain" do
          expect{delete "/v2/organizations/#{org.guid}/domains/#{domain.guid}", {},
                 headers_for(@org_a_manager)}.not_to change{SharedDomain.count}
          last_response.status.should == 301

          warning_header = CGI.unescape(last_response.headers["X-Cf-Warnings"])
          expect(warning_header).to eq("Endpoint removed")
        end
      end

      describe "GET /v2/organizations/:guid/domains/:guid" do
        it "should be deprecated" do
          get "/v2/organizations/#{org.guid}/domains/#{domain.guid}"
          expect(last_response).to be_a_deprecated_response
        end
      end

      describe "PUT /v2/organizations/:guid/domains/:domain_guid" do
        it "should be deprecated" do
          put "/v2/organizations/#{org.guid}/domains/#{domain.guid}", {}, admin_headers
          expect(last_response.status).to eql(201)
          expect(last_response).to be_a_deprecated_response
        end
      end

      describe "PUT /v2/organizations/:guid/domains/:private_domain_guid" do
        let(:private_domain) { PrivateDomain.make(owning_organization: org) }
        it "should be deprecated" do
          expect(org.domains).to include(private_domain)
          put "/v2/organizations/#{org.guid}/domains/#{private_domain.guid}", {}, admin_headers
          expect(last_response.status).to eql(201)
          expect(last_response).to be_a_deprecated_response
        end
      end
    end

    describe "Removing a user from the organization" do
      let(:user) { User.make }
      let(:org) { Organization.make(:user_guids => [user.guid]) }
      let(:org_space_empty) { Space.make(organization: org) }
      let(:org_space_full)  { Space.make(organization: org, :manager_guids => [user.guid], :developer_guids => [user.guid], :auditor_guids => [user.guid]) }

      def update_org_user user_guid
        put "/v2/organizations/#{org.guid}", Yajl::Encoder.encode(user_guid), admin_headers
      end

      def remove_org_user user_guid
        delete "/v2/organizations/#{org.guid}/users/#{user_guid}", {}, admin_headers
      end

      def remove_org_user_recursive user_guid
        delete "/v2/organizations/#{org.guid}/users/#{user_guid}?recursive=true", {}, admin_headers
      end

      context "DELETE /v2/organizations/org_guid/users/user_guid" do
        context "without the recursive flag" do
          context "a single organization" do
            it "should remove the user from the organization if that user does not belong to any space" do
              org.add_space(org_space_empty)
              org.users.should include(user)
              remove_org_user(user.guid)
              org.refresh

              org.user_guids.should_not include(user)
            end

            it "should not remove the user from the organization if that user belongs to a space associated with the organization" do
              org.add_space(org_space_full)
              remove_org_user(user.guid)

              expect(last_response.status).to eql(400)
              org.refresh
              org.users.should include(user)
            end
          end
        end

        context "with recursive flag" do
          context "a single organization" do
            it "should remove the user from each space that is associated with the organization" do
              org.add_space(org_space_full)
              ["developers", "auditors", "managers"].each { |type| org_space_full.send(type).should include(user) }
              remove_org_user_recursive(user.guid)
              org_space_full.refresh

              ["developers", "auditors", "managers"].each { |type| org_space_full.send(type).should_not include(user) }
            end

            it "should remove the user from the organization" do
              org.add_space(org_space_full)
              org.users.should include(user)
              remove_org_user_recursive(user.guid)
              org.refresh

              org.users.should_not include(user)
            end
          end

          context "multiple organizations" do
            let(:org_2) { Organization.make(:user_guids => [user.guid]) }
            let(:org2_space) { Space.make(organization: org_2, :developer_guids => [user.guid]) }

            it "should remove a user from one organization, but no the other" do
              org.add_space(org_space_full)
              org_2.add_space(org2_space)
              [org, org_2].each { |organization| organization.users.should include(user) }
              remove_org_user_recursive(user.guid)

              [org, org_2].each { |organization| organization.refresh }
              org.users.should_not include(user)
              org_2.users.should include(user)
            end

            it "should remove a user from each space associated with the organization being removed, but not the other" do
              org.add_space(org_space_full)
              org_2.add_space(org2_space)
              ["developers", "auditors", "managers"].each { |type| org_space_full.send(type).should include(user) }
              org2_space.developers.should include(user)
              remove_org_user_recursive(user.guid)

              [org_space_full, org2_space].each { |space| space.refresh }
              ["developers", "auditors", "managers"].each { |type| org_space_full.send(type).should_not include(user) }
              org2_space.developers.should include(user)
            end
          end
        end
      end

      context "PUT /v2/organizations/org_guid" do
        it "should remove the user if that user does not belong to any space associated with the organization" do
          org.add_space(org_space_empty)
          org.users.should include(user)
          update_org_user("user_guids" => [])
          org.refresh
          org.users.should_not include(user)
        end

        it "should not remove the user if they attempt to delete the user through an update" do
          org.add_space(org_space_full)
          update_org_user("user_guids" => [])
          expect(last_response.status).to eql(400)
          org.refresh
          org.users.should include(user)
        end
      end
    end
  end
end
