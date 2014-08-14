require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::SpaceQuotaDefinitionsController do

    describe "Attributes" do
      it do
        expect(described_class).to have_creatable_attributes({
          name:                       { type: "string", required: true },
          non_basic_services_allowed: { type: "bool", required: true },
          total_services:             { type: "integer", required: true },
          total_routes:               { type: "integer", required: true },
          memory_limit:               { type: "integer", required: true },
          instance_memory_limit:      { type: "integer" },
          organization_guid:          { type: "string", required: true },
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name:                       { type: "string" },
          non_basic_services_allowed: { type: "bool" },
          total_services:             { type: "integer" },
          total_routes:               { type: "integer" },
          memory_limit:               { type: "integer" },
          instance_memory_limit:      { type: "integer" },
          organization_guid:          { type: "string" },
        })
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = SpaceQuotaDefinition.make(organization_guid: @org_a.guid)
        @obj_b = SpaceQuotaDefinition.make(organization_guid: @org_b.guid)

        @space_a.space_quota_definition = @obj_a
        @space_a.save
        @space_b.space_quota_definition = @obj_b
        @space_b.save
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission enumeration", "OrgManager",
            :name      => "space_quota_definition",
            :path      => "/v2/space_quota_definitions",
            :enumerate => 1
        end

        describe "OrgManager of both" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          before do
            @org_b.add_user(@org_a_manager)
            @org_b.add_manager(@org_a_manager)
          end

          include_examples "permission enumeration", "OrgManager",
            :permissions_overlap => true,
            :name      => "space_quota_definition",
            :path      => "/v2/space_quota_definitions",
            :enumerate => 2
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission enumeration", "OrgUser",
            :name      => "space_quota_definition",
            :path      => "/v2/space_quota_definitions",
            :enumerate => 0
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission enumeration", "BillingManager",
            :name      => "space_quota_definition",
            :path      => "/v2/space_quota_definitions",
            :enumerate => 0
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission enumeration", "Auditor",
            :name      => "space_quota_definition",
            :path      => "/v2/space_quota_definitions",
            :enumerate => 0
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "permission enumeration", "SpaceManager",
            :name      => "space_quota_definition",
            :path      => "/v2/space_quota_definitions",
            :enumerate => 1
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission enumeration", "Developer",
            :name      => "space_quota_definition",
            :path      => "/v2/space_quota_definitions",
            :enumerate => 1
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission enumeration", "SpaceAuditor",
            :name      => "space_quota_definition",
            :path      => "/v2/space_quota_definitions",
            :enumerate => 1
        end
      end
    end

    describe "errors" do
      let(:org) { Organization.make }

      it "returns SpaceQuotaDefinitionInvalid" do
        sqd_json = { name: '', non_basic_services_allowed: true, total_services: 1, total_routes: 1, memory_limit: 2, organization_guid: org.guid }
        post "/v2/space_quota_definitions", MultiJson.dump(sqd_json), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["description"]).to match(/Space Quota Definition is invalid/)
        expect(decoded_response["error_code"]).to match(/SpaceQuotaDefinitionInvalid/)
      end

      it "returns SpaceQuotaDefinitionNameTaken errors on unique name errors" do
        SpaceQuotaDefinition.make(name: "foo", organization: org)
        sqd_json = { name: 'foo', non_basic_services_allowed: true, total_services: 1, total_routes: 1, memory_limit: 2, organization_guid: org.guid }
        post "/v2/space_quota_definitions", MultiJson.dump(sqd_json), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["description"]).to match(/name is taken/)
        expect(decoded_response["error_code"]).to match(/SpaceQuotaDefinitionNameTaken/)
      end
    end
  end
end
