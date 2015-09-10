require 'spec_helper'
require 'queries/space_user_roles_fetcher'

module VCAP::CloudController
  describe SpaceUserRolesFetcher do
    describe '#fetch' do
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }
      let(:everything_user) { User.make }
      let(:manager) { User.make }
      let(:auditor) { User.make }
      let(:developer) { User.make }
      let(:not_a_user) { User.make }

      before do
        org.add_user(everything_user)
        org.add_user(manager)
        org.add_user(auditor)
        org.add_user(developer)
        org.add_user(not_a_user)

        space.add_manager(everything_user)
        space.add_manager(manager)

        space.add_auditor(everything_user)
        space.add_auditor(auditor)

        space.add_developer(everything_user)
        space.add_developer(developer)
      end

      it 'should return a list of all users with their associated roles' do
        users = SpaceUserRolesFetcher.new.fetch(space)
        expect(users).to include(everything_user, manager, auditor, developer)
        expect(users).not_to include(not_a_user)
      end
    end
  end
end
