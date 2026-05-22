require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServicePlanVisibility, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :service_plan }
      it { is_expected.to have_associated :organization }
    end

    describe 'uniqueness' do
      it 'enforces uniqueness of organization and service plan combination' do
        existing = create(:service_plan_visibility)
        expect do
          ServicePlanVisibility.create(service_plan: existing.service_plan, organization: existing.organization)
        end.to raise_error(Sequel::ValidationFailed, /unique/)
      end
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :service_plan }
      it { is_expected.to validate_presence :organization }

      context 'when the service plan visibility is for a private broker' do
        it 'returns a validation error' do
          organization = create(:organization)
          space = create(:space, organization:)
          private_broker = create(:service_broker, space:)
          service = create(:service, service_broker: private_broker, active: true)
          plan = create(:service_plan, service: service, public: false)

          expect do
            ServicePlanVisibility.create service_plan: plan, organization: organization
          end.to raise_error Sequel::ValidationFailed, 'service_plan is from a private broker'
        end
      end

      context 'when the service plan visibility is for a public plan' do
        it 'returns a validation error' do
          organization = create(:organization)
          private_broker = create(:service_broker)
          service = create(:service, service_broker: private_broker, active: true)
          plan = create(:service_plan, service: service, public: true)

          expect do
            ServicePlanVisibility.create service_plan: plan, organization: organization
          end.to raise_error Sequel::ValidationFailed, 'service_plan is publicly available'
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :service_plan_guid, :organization_guid }
      it { is_expected.to import_attributes :service_plan_guid, :organization_guid }
    end

    describe '.visible_private_plan_ids_for_user(user)' do
      let!(:user) { create(:user) }
      let!(:org1) { create(:organization) }
      let!(:org2) { create(:organization) }
      let!(:org3) { create(:organization) }

      let!(:plan_visible_to_both) { create(:service_plan, public: false) }
      let!(:plan_visible_to_org1) { create(:service_plan, public: false) }
      let!(:plan_visible_to_org2) { create(:service_plan, public: false) }
      let!(:plan_hidden_from_both) { create(:service_plan, public: false) }
      let!(:plan_not_visible_to_users_org) { create(:service_plan, public: false) }

      before do
        user.add_organization(org1)
        user.add_organization(org2)
        create(:service_plan_visibility, organization: org1, service_plan: plan_visible_to_both)
        create(:service_plan_visibility, organization: org2, service_plan: plan_visible_to_both)
        create(:service_plan_visibility, organization: org1, service_plan: plan_visible_to_org1)
        create(:service_plan_visibility, organization: org2, service_plan: plan_visible_to_org2)
        create(:service_plan_visibility, organization: org3, service_plan: plan_not_visible_to_users_org)
      end

      it "returns the list of ids for plans the user's orgs can see" do
        expect(ServicePlanVisibility.visible_private_plan_ids_for_user(user).select_map(:service_plan_id)).to contain_exactly(plan_visible_to_both.id, plan_visible_to_org1.id,
                                                                                                                              plan_visible_to_org2.id)
      end
    end

    describe '.visible_private_plan_ids_for_organization' do
      let!(:organization) { create(:organization) }
      let!(:visible_plan) { create(:service_plan, public: false) }
      let!(:hidden_plan) { create(:service_plan, public: false) }

      before do
        create(:service_plan_visibility, organization: organization, service_plan: visible_plan)
      end

      it "returns the list of ids for plans the user's orgs can see" do
        expect(ServicePlanVisibility.visible_private_plan_ids_for_organization(organization.id).select_map(:service_plan_id)).to contain_exactly(visible_plan.id)
      end
    end
  end
end
