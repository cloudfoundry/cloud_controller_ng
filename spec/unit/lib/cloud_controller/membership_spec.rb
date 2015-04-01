require 'spec_helper'

module VCAP::CloudController
  describe Membership do
    let(:user) { User.make }
    let(:space) { Space.make(organization: organization) }
    let(:space_whose_org_is_suspended) { Space.make(organization: suspended_organization) }
    let(:space_that_user_doesnt_develop_in) { Space.make(organization: organization) }
    let(:organization) { Organization.make }
    let(:suspended_organization) { Organization.make(status: 'suspended') }
    let(:space_in_some_other_org) { Space.make }

    subject(:membership) { Membership.new(user) }

    describe '#spaces' do
      before do
        organization.add_user(user)
        suspended_organization.add_user(user)
        space.add_developer(user)
        space_whose_org_is_suspended.add_developer(user)
      end

      it 'only returns the spaces for an active org' do
        expect(membership.spaces(roles: %i(developer))).not_to include space_whose_org_is_suspended
        expect(membership.spaces(roles: %i(developer))).not_to include space_that_user_doesnt_develop_in
        expect(membership.spaces(roles: %i(developer))).not_to include space_in_some_other_org
        expect(membership.spaces(roles: %i(developer))).to include space
      end
    end

    describe '#space_role?' do
      before do
        organization.add_user(user)
        suspended_organization.add_user(user)
        space.add_developer(user)
        space_whose_org_is_suspended.add_developer(user)
      end

      it 'is true for spaces where the user is a developer' do
        expect(membership.space_role?(:developer, space.guid)).to be_truthy
      end

      it 'is false for spaces in which the org is suspended' do
        expect(membership.space_role?(:developer, space_whose_org_is_suspended.guid)).to be_falsey
      end

      it 'is false for spaces where the user is not a developer in' do
        expect(membership.space_role?(:developer, space_that_user_doesnt_develop_in.guid)).to be_falsey
      end
    end
  end
end
