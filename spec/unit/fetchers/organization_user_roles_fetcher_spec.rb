require 'db_spec_helper'
require 'fetchers/organization_user_roles_fetcher'

module VCAP::CloudController
  RSpec.describe OrganizationUserRolesFetcher do
    describe '#fetch' do
      let(:org) { create(:organization) }
      let(:everything_user) { create(:user) }
      let(:manager) { create(:user) }
      let(:auditor) { create(:user) }
      let(:biller) { create(:user) }
      let(:user) { create(:user) }
      let!(:not_a_user) { create(:user) }
      let(:admin) { false }

      before do
        org.add_user(everything_user)
        org.add_user(user)
        org.add_manager(everything_user)
        org.add_manager(manager)
        org.add_auditor(everything_user)
        org.add_auditor(auditor)
        org.add_billing_manager(everything_user)
        org.add_billing_manager(biller)
      end

      context 'when no user_guid filter is provided' do
        it 'returns a list of all users with their associated roles' do
          users = OrganizationUserRolesFetcher.fetch(org).to_a
          expect(users).to include(everything_user, manager, auditor, biller, user)
          expect(users).not_to include(not_a_user)
        end
      end

      context 'when a user_guid is specified' do
        it 'returns a list of associated roles for that user_guid' do
          users = OrganizationUserRolesFetcher.fetch(org, user_guid: auditor.guid).to_a
          expect(users.map(&:guid)).to include(auditor.guid)
          expect(users.map(&:guid)).not_to include(everything_user.guid, manager.guid, biller.guid, user.guid, not_a_user.guid)
        end
      end
    end
  end
end
