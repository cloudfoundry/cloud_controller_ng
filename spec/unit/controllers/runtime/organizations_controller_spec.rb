require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::OrganizationsController do
    let(:org) { Organization.make }

    describe "Query Parameters" do
      it { expect(described_class).to be_queryable_by(:name) }
      it { expect(described_class).to be_queryable_by(:space_guid) }
      it { expect(described_class).to be_queryable_by(:user_guid) }
      it { expect(described_class).to be_queryable_by(:manager_guid) }
      it { expect(described_class).to be_queryable_by(:billing_manager_guid) }
      it { expect(described_class).to be_queryable_by(:auditor_guid) }
      it { expect(described_class).to be_queryable_by(:status) }
    end

    describe "Attributes" do
      it do
        expect(described_class).to have_creatable_attributes({
          name: {type: "string", required: true},
          billing_enabled: {type: "bool", default: false},
          status: {type: "string", default: "active"},
          quota_definition_guid: {type: "string"},
          domain_guids: {type: "[string]"},
          private_domain_guids: {type: "[string]"},
          user_guids: {type: "[string]"},
          manager_guids: {type: "[string]"},
          billing_manager_guids: {type: "[string]"},
          auditor_guids: {type: "[string]"},
          app_event_guids: {type: "[string]"}
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: {type: "string"},
          billing_enabled: {type: "bool"},
          status: {type: "string"},
          quota_definition_guid: {type: "string"},
          domain_guids: {type: "[string]"},
          private_domain_guids: {type: "[string]"},
          user_guids: {type: "[string]"},
          manager_guids: {type: "[string]"},
          billing_manager_guids: {type: "[string]"},
          auditor_guids: {type: "[string]"},
          app_event_guids: {type: "[string]"},
          space_guids: {type: "[string]"},
          space_quota_definition_guids: {type: "[string]" }
        })
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = @org_a
        @obj_b = @org_b
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

    describe 'GET /v2/organizations/:guid/domains' do
      let(:organization) { Organization.make }
      let(:manager) { make_manager_for_org(organization) }

      before do
        PrivateDomain.make(owning_organization: organization)
      end

      it "should return the private domains associated with the organization and all shared domains" do
        get "/v2/organizations/#{organization.guid}/domains", {}, headers_for(manager)
        expect(last_response.status).to eq(200)
        resources = decoded_response.fetch("resources")
        guids = resources.map { |x| x["metadata"]["guid"] }
        expect(guids).to match_array(organization.domains.map(&:guid))
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

    describe "Deprecated endpoints" do
      describe "GET /v2/organizations/:guid/domains" do
        it "should be deprecated" do
          get "/v2/organizations/#{org.guid}/domains", "", admin_headers
          expect(last_response).to be_a_deprecated_response
        end
      end
    end

    describe "Removing a user from the organization" do
      let(:user) { User.make }
      let(:org) { Organization.make(:user_guids => [user.guid]) }
      let(:org_space_empty) { Space.make(organization: org) }
      let(:org_space_full)  { Space.make(organization: org, :manager_guids => [user.guid], :developer_guids => [user.guid], :auditor_guids => [user.guid]) }

      context "DELETE /v2/organizations/org_guid/users/user_guid" do
        context "without the recursive flag" do
          context "a single organization" do
            it "should remove the user from the organization if that user does not belong to any space" do
              org.add_space(org_space_empty)
              expect(org.users).to include(user)
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}", {}, admin_headers
              org.refresh

              expect(org.user_guids).not_to include(user)
            end

            it "should not remove the user from the organization if that user belongs to a space associated with the organization" do
              org.add_space(org_space_full)
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}", {}, admin_headers

              expect(last_response.status).to eql(400)
              org.refresh
              expect(org.users).to include(user)
            end
          end
        end

        context "with recursive flag" do
          context "a single organization" do
            it "should remove the user from each space that is associated with the organization" do
              org.add_space(org_space_full)
              ["developers", "auditors", "managers"].each { |type| expect(org_space_full.send(type)).to include(user) }
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}?recursive=true", {}, admin_headers
              org_space_full.refresh

              ["developers", "auditors", "managers"].each { |type| expect(org_space_full.send(type)).not_to include(user) }
            end

            it "should remove the user from the organization" do
              org.add_space(org_space_full)
              expect(org.users).to include(user)
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}?recursive=true", {}, admin_headers
              org.refresh

              expect(org.users).not_to include(user)
            end
          end

          context "multiple organizations" do
            let(:org_2) { Organization.make(:user_guids => [user.guid]) }
            let(:org2_space) { Space.make(organization: org_2, :developer_guids => [user.guid]) }

            it "should remove a user from one organization, but no the other" do
              org.add_space(org_space_full)
              org_2.add_space(org2_space)
              [org, org_2].each { |organization| expect(organization.users).to include(user) }
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}?recursive=true", {}, admin_headers

              [org, org_2].each { |organization| organization.refresh }
              expect(org.users).not_to include(user)
              expect(org_2.users).to include(user)
            end

            it "should remove a user from each space associated with the organization being removed, but not the other" do
              org.add_space(org_space_full)
              org_2.add_space(org2_space)
              ["developers", "auditors", "managers"].each { |type| expect(org_space_full.send(type)).to include(user) }
              expect(org2_space.developers).to include(user)
              delete "/v2/organizations/#{org.guid}/users/#{user.guid}?recursive=true", {}, admin_headers

              [org_space_full, org2_space].each { |space| space.refresh }
              ["developers", "auditors", "managers"].each { |type| expect(org_space_full.send(type)).not_to include(user) }
              expect(org2_space.developers).to include(user)
            end
          end
        end
      end

      context "PUT /v2/organizations/org_guid" do
        it "should remove the user if that user does not belong to any space associated with the organization" do
          org.add_space(org_space_empty)
          expect(org.users).to include(user)
          put "/v2/organizations/#{org.guid}", MultiJson.dump("user_guids" => []), admin_headers
          org.refresh
          expect(org.users).not_to include(user)
        end

        it "should not remove the user if they attempt to delete the user through an update" do
          org.add_space(org_space_full)
          put "/v2/organizations/#{org.guid}", MultiJson.dump("user_guids" => []), admin_headers
          expect(last_response.status).to eql(400)
          org.refresh
          expect(org.users).to include(user)
        end
      end
    end

    describe "when the default quota does not exist" do
      before { QuotaDefinition.default.destroy }

      it "returns an OrganizationInvalid message" do
        post "/v2/organizations", MultiJson.dump({name: "gotcha"}), admin_headers
        expect(last_response.status).to eql(400)
        expect(decoded_response["code"]).to eq(30001)
        expect(decoded_response["description"]).to include("Quota Definition could not be found")
      end
    end
  end
end
