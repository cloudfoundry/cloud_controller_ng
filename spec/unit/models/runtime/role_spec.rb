require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::Role, type: :model do
    it { is_expected.to have_timestamp_columns }

    context 'when there are roles' do
      let(:user) { User.make }
      let(:org) { Organization.make }
      let(:space) { Space.make }
      let!(:organization_user) { OrganizationUser.make(user: user, organization: org) }
      let!(:organization_manager) { OrganizationManager.make(organization: org) }
      let!(:organization_billing_manager) { OrganizationBillingManager.make }
      let!(:organization_auditor) { OrganizationAuditor.make }
      let!(:space_developer) { SpaceDeveloper.make(user: user, space: space) }
      let!(:space_auditor) { SpaceAuditor.make(space: space) }
      let!(:space_manager) { SpaceManager.make }
      let!(:space_supporter) { SpaceSupporter.make }

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
        expect(roles[VCAP::CloudController::RoleTypes::SPACE_SUPPORTER]).to be_a_guid
      end

      context 'optimized SQL queries' do
        before do
          OrganizationUser.make
        end

        it 'works for different filters' do
          expect {
            expect(Role.where(type: VCAP::CloudController::RoleTypes::ORGANIZATION_USER).count).to eq(2)
            expect(Role.where(guid: organization_manager.guid).count).to eq(1)
            expect(Role.where(user_id: user.id).count).to eq(2)
            expect(Role.where(organization_id: org.id).count).to eq(2)
            expect(Role.where(space_id: space.id).count).to eq(2)
          }.to have_queried_db_times(/((\bwhere\b).*?){8}/i, 5) # SQL statement has eight WHERE conditions, one per UNIONed table.
        end

        it 'works for combined filters' do
          expect {
            expect(Role.where(type: VCAP::CloudController::RoleTypes::ORGANIZATION_USER).where(organization_id: org.id).count).to eq(1)
            expect(Role.where(user_id: user.id).where(space_id: space.id).count).to eq(1)
          }.to have_queried_db_times(/((\bwhere\b).*?){8}/i, 2) # SQL statement has eight WHERE conditions, one per UNIONed table.
        end

        it 'works for filters applied with table name prefix' do
          expect {
            expect(Role.where(t1__guid: organization_billing_manager.guid).count).to eq(1)
          }.to have_queried_db_times(/((\bwhere\b).*?){8}/i, 1) # SQL statement has eight WHERE conditions, one per UNIONed table.
        end
      end
    end
  end
end
