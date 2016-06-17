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

      it 'should return a list of all users with their associated roles' do
        users = OrganizationUserRolesFetcher.new.fetch(org)
        expect(users).to include(everything_user, manager, auditor, biller, user)
        expect(users).not_to include(not_a_user)
      end
    end
  end
end
