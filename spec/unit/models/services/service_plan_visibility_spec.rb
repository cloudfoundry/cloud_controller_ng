require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServicePlanVisibility, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :service_plan }
      it { is_expected.to have_associated :organization }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :service_plan }
      it { is_expected.to validate_presence :organization }
      it { is_expected.to validate_uniqueness [:organization_id, :service_plan_id] }

      context 'when the service plan visibility is for a private broker' do
        it 'returns a validation error' do
          organization = Organization.make
          space = Space.make organization: organization
          private_broker = ServiceBroker.make space: space
          service = Service.make service_broker: private_broker, active: true
          plan = ServicePlan.make service: service

          expect {
            ServicePlanVisibility.create service_plan: plan, organization: organization
          }.to raise_error Sequel::ValidationFailed, 'service_plan is from a private broker'
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :service_plan_guid, :organization_guid }
      it { is_expected.to import_attributes :service_plan_guid, :organization_guid }
    end

    describe '.visible_private_plan_ids_for_user(user)' do
      let!(:user) { User.make }
      let!(:org1) { Organization.make }
      let!(:org2) { Organization.make }
      let!(:org3) { Organization.make }

      let!(:plan_visible_to_both) { ServicePlan.make(public: false) }
      let!(:plan_visible_to_org1) { ServicePlan.make(public: false) }
      let!(:plan_visible_to_org2) { ServicePlan.make(public: false) }
      let!(:plan_hidden_from_both) { ServicePlan.make(public: false) }
      let!(:plan_not_visible_to_users_org) { ServicePlan.make(public: false) }

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
        expect(ServicePlanVisibility.visible_private_plan_ids_for_user(user)).to match_array([
          plan_visible_to_both.id, plan_visible_to_org1.id, plan_visible_to_org2.id
        ])
      end
    end

    describe '.visible_private_plan_ids_for_organization' do
      let!(:organization) { Organization.make }
      let!(:visible_plan) { ServicePlan.make(public: false) }
      let!(:hidden_plan) { ServicePlan.make(public: false) }

      before do
        ServicePlanVisibility.make(organization: organization, service_plan: visible_plan)
      end

      it "returns the list of ids for plans the user's orgs can see" do
        expect(ServicePlanVisibility.visible_private_plan_ids_for_organization(organization)).to match_array([visible_plan.id])
      end
    end
  end
end
