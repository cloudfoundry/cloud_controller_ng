require "spec_helper"

describe MaxServiceInstancePolicy do
  describe "#check_quota" do
    let(:org) { VCAP::CloudController::Organization.make quota_definition: quota }
    let(:space) { VCAP::CloudController::Space.make organization: org }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make }
    let(:service_instance) { make_organization_service_instance }
    let(:quota) { VCAP::CloudController::QuotaDefinition.make total_services: 2 }

    subject(:policy) { MaxServiceInstancePolicy.new(org, service_instance) }

    def make_organization_service_instance
      VCAP::CloudController::ManagedServiceInstance.make space: space, service_plan: service_plan
    end

    context "when the quota is not reached" do
      it "should return true when quota is not reached" do
        policy.check_quota
        expect(service_instance.errors).to be_empty
      end
    end

    context "when the quota is unlimited" do
      let(:quota) { VCAP::CloudController::QuotaDefinition.make total_services: -1 }

      before { 2.times { make_organization_service_instance } }

      it "should return true when quota is not reached" do
        policy.check_quota
        expect(service_instance.errors).to be_empty
      end
    end

    context "when the quota is reached" do
      before { 2.times { make_organization_service_instance } }

      context "and basic services are not allowed" do
        before { quota.update(non_basic_services_allowed: false) }

        context "and the service plan is free" do
          before { service_plan.update(free: true) }

          it "adds a free_quota_exceeded error on the org" do
            policy.check_quota
            expect(service_instance.errors.on(:org)).to include(:free_quota_exceeded)
          end
        end

        context "and the service plan is paid" do
          before { service_plan.update(free: false) }

          it "adds a paid_quota_exceeded error on the org" do
            policy.check_quota
            expect(service_instance.errors.on(:service_plan)).to include(:paid_services_not_allowed)
          end
        end
      end

      context "and basic services are allowed" do
        before { quota.update(non_basic_services_allowed: true) }

        context "and the service plan is free" do
          before { service_plan.update(free: true) }

          it "adds a free_quota_exceeded error on the org" do
            policy.check_quota
            expect(service_instance.errors.on(:org)).to include(:paid_quota_exceeded)
          end
        end

        context "and the service plan is paid" do
          before { service_plan.update(free: false) }

          it "adds a paid_quota_exceeded error on the org" do
            policy.check_quota
            expect(service_instance.errors.on(:org)).to include(:paid_quota_exceeded)
          end
        end
      end
    end
  end
end
