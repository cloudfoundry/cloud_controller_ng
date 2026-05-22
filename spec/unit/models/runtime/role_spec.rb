require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::Role, type: :model do
    it { is_expected.to have_timestamp_columns }

    context 'when there are roles' do
      let(:user) { create(:user) }
      let(:org) { create(:organization) }
      let(:space) { create(:space) }
      let!(:organization_user) { create(:organization_user, user: user, organization: org) }
      let!(:organization_manager) { create(:organization_manager, organization: org) }
      let!(:organization_billing_manager) { create(:organization_billing_manager) }
      let!(:organization_auditor) { create(:organization_auditor) }
      let!(:space_developer) { create(:space_developer, user:, space:) }
      let!(:space_auditor) { create(:space_auditor, space:) }
      let!(:space_manager) { create(:space_manager) }
      let!(:space_supporter) { create(:space_supporter) }

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
          create(:organization_user)
        end

        it 'works for different filters' do
          # SQL statement has eight WHERE conditions, one per UNIONed table.
          expect do
            expect(Role.where(type: VCAP::CloudController::RoleTypes::ORGANIZATION_USER).count).to eq(2)
            expect(Role.where(guid: organization_manager.guid).count).to eq(1)
            expect(Role.where(user_id: user.id).count).to eq(2)
            expect(Role.where(organization_id: org.id).count).to eq(2)
            expect(Role.where(space_id: space.id).count).to eq(2)
          end.to have_queried_db_times(/((\bwhere\b).*?){8}/i, 5)
        end

        it 'works for combined filters' do
          # SQL statement has eight WHERE conditions, one per UNIONed table.
          expect do
            expect(Role.where(type: VCAP::CloudController::RoleTypes::ORGANIZATION_USER).where(organization_id: org.id).count).to eq(1)
            expect(Role.where(user_id: user.id).where(space_id: space.id).count).to eq(1)
          end.to have_queried_db_times(/((\bwhere\b).*?){8}/i, 2)
        end

        it 'works for filters applied with table name prefix' do
          # SQL statement has eight WHERE conditions, one per UNIONed table.
          expect do
            expect(Role.where(t1__guid: organization_billing_manager.guid).count).to eq(1)
          end.to have_queried_db_times(/((\bwhere\b).*?){8}/i, 1)
        end
      end
    end
  end
end
