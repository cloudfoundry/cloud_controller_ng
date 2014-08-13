require "spec_helper"

module VCAP::CloudController
  describe ServicePlanVisibilitiesController, :services do
    describe "Attributes" do
      it do
        expect(described_class).to have_creatable_attributes({
          service_plan_guid: {type: "string", required: true},
          organization_guid: {type: "string", required: true}
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          service_plan_guid: {type: "string"},
          organization_guid: {type: "string"}
        })
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = ServicePlanVisibility.make
        @obj_b = ServicePlanVisibility.make
      end

      def self.user_sees_empty_enumerate(user_role, member_a_ivar, member_b_ivar)
        describe user_role do
          let(:member_a) { instance_variable_get(member_a_ivar) }
          let(:member_b) { instance_variable_get(member_b_ivar) }

          include_examples "permission enumeration", user_role,
                           :name => 'service plan visibility',
                           :path => "/v2/service_plan_visibilities",
                           :enumerate => 0
        end
      end

      user_sees_empty_enumerate("Developer",      :@space_a_developer,     :@space_b_developer)
      user_sees_empty_enumerate("OrgManager",     :@org_a_manager,         :@org_b_manager)
      user_sees_empty_enumerate("OrgUser",        :@org_a_member,          :@org_b_member)
      user_sees_empty_enumerate("BillingManager", :@org_a_billing_manager, :@org_b_billing_manager)
      user_sees_empty_enumerate("Auditor",        :@org_a_auditor,         :@org_b_auditor)
      user_sees_empty_enumerate("SpaceManager",   :@space_a_manager,       :@space_b_manager)
      user_sees_empty_enumerate("SpaceAuditor",   :@space_a_auditor,       :@space_b_auditor)
    end

    describe "Query Parameters" do
      it { expect(described_class).to be_queryable_by(:organization_guid) }
      it { expect(described_class).to be_queryable_by(:service_plan_guid) }
    end
  end
end
