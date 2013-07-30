require "spec_helper"

module VCAP::CloudController::Models
  describe ServicePlanVisibility, type: :model do
    it_behaves_like "a CloudController model", {
      :required_attributes    => [:service_plan, :organization],
      :unique_attributes      => [:service_plan, :organization],
    }
  end

  describe ".visible_private_plan_ids_for_user(user)" do
    let!(:user) { User.make }
    let!(:org1) { Organization.make }
    let!(:org2) { Organization.make }
    let!(:org3) { Organization.make }

    let!(:plan_visible_to_both)  { ServicePlan.make(public: false) }
    let!(:plan_visible_to_org1)  { ServicePlan.make(public: false) }
    let!(:plan_visible_to_org2)  { ServicePlan.make(public: false) }
    let!(:plan_hidden_from_both) { ServicePlan.make(public: false) }
    let!(:plan_not_visible_to_users_org)  { ServicePlan.make(public: false) }

    before do
      user.add_organization(org1)
      user.add_organization(org2)
      ServicePlanVisibility.make(organization: org1, service_plan: plan_visible_to_both)
      ServicePlanVisibility.make(organization: org2, service_plan: plan_visible_to_both)
      ServicePlanVisibility.make(organization: org1, service_plan: plan_visible_to_org1)
      ServicePlanVisibility.make(organization: org2, service_plan: plan_visible_to_org2)
      ServicePlanVisibility.make(organization: org3, service_plan: plan_not_visible_to_users_org)
    end

    it "returns the list of ids for plans the user's orgs can see" do
      ServicePlanVisibility.visible_private_plan_ids_for_user(user).should =~ [
        plan_visible_to_both.id, plan_visible_to_org1.id, plan_visible_to_org2.id
      ]
    end
  end

  describe ".visible_private_plan_ids_for_organization" do
    let!(:organization) { Organization.make }
    let!(:visible_plan) { ServicePlan.make(public: false) }
    let!(:hidden_plan) { ServicePlan.make(public: false) }

    before do
      ServicePlanVisibility.make(organization: organization, service_plan: visible_plan)
    end

    it "returns the list of ids for plans the user's orgs can see" do
      ServicePlanVisibility.visible_private_plan_ids_for_organization(organization).should =~ [visible_plan.id]
    end
  end
end
