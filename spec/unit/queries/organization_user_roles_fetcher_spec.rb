require 'spec_helper'
require 'queries/organization_user_roles_fetcher'

module VCAP::CloudController
  RSpec.describe OrganizationUserRolesFetcher do
    describe '#fetch' do
      let(:org) { Organization.make }
      let(:everything_user) { User.make }
      let(:manager) { User.make }
      let(:auditor) { User.make }
      let(:biller) { User.make }
      let(:user) { User.make }
      let!(:not_a_user) { User.make }
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
        it 'should return a list of all users with their associated roles' do
          users = OrganizationUserRolesFetcher.fetch(org)
          expect(users).to include(everything_user, manager, auditor, biller, user)
          expect(users).not_to include(not_a_user)
        end
      end

      context 'when a user_guid is specified' do
        it 'should return a list of associated roles for that user_guid' do
          users = OrganizationUserRolesFetcher.fetch(org, user_guid: auditor.guid)
          expect(users.map(&:guid)).to include(auditor.guid)
          expect(users.map(&:guid)).not_to include(everything_user.guid, manager.guid, biller.guid, user.guid, not_a_user.guid)
        end
      end
    end
  end
end
