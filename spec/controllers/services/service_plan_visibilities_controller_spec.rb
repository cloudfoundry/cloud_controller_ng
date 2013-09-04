require "spec_helper"

module VCAP::CloudController
  describe ServicePlanVisibilitiesController, :services, type: :controller do
    service_plan_visibility_path = "/v2/service_plan_visibilities"
    include_examples "creating", path: service_plan_visibility_path,
                     model: ServicePlanVisibility,
                     required_attributes: %w(organization_guid service_plan_guid),
                     unique_attributes: %w(organization_guid service_plan_guid)

    include_examples "enumerating objects", path: service_plan_visibility_path,
                     model: ServicePlanVisibility

    include_examples "deleting a valid object", path: service_plan_visibility_path,
                     model: ServicePlanVisibility


    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = ServicePlanVisibility.make
        @obj_b = ServicePlanVisibility.make
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :service_plan_guid => ServicePlan.make.guid,
          :organization_guid => @org_a.guid,
        )
      end
      let(:update_req_for_a) {"{}"} # update is not implemented

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
  end
end
