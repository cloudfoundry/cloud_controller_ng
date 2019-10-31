require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::Role, type: :model do
    it { is_expected.to have_timestamp_columns }

    context 'when there are roles' do
      let!(:organization_user) { OrganizationUser.make }
      let!(:organization_manager) { OrganizationManager.make }
      let!(:organization_billing_manager) { OrganizationBillingManager.make }
      let!(:organization_auditor) { OrganizationAuditor.make }
      let!(:space_developer) { SpaceDeveloper.make }
      let!(:space_auditor) { SpaceAuditor.make }
      let!(:space_manager) { SpaceManager.make }

      it 'contains all the roles' do
        roles = VCAP::CloudController::Role.all.each_with_object({}) do |role, obj|
          obj[role.type] = role.guid
        end

        expect(roles[VCAP::CloudController::RoleTypes::ORGANIZATION_USER]).to be_a_guid
        expect(roles[VCAP::CloudController::RoleTypes::ORGANIZATION_MANAGER]).to be_a_guid
        expect(roles[VCAP::CloudController::RoleTypes::ORGANIZATION_BILLING_MANAGER]).to be_a_guid
        expect(roles[VCAP::CloudController::RoleTypes::ORGANIZATION_AUDITOR]).to be_a_guid
        expect(roles[VCAP::CloudController::RoleTypes::SPACE_DEVELOPER]).to be_a_guid
        expect(roles[VCAP::CloudController::RoleTypes::SPACE_AUDITOR]).to be_a_guid
        expect(roles[VCAP::CloudController::RoleTypes::SPACE_MANAGER]).to be_a_guid
      end
    end
  end
end
