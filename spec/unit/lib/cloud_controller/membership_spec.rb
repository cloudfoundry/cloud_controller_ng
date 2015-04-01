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

    describe '#developed_spaces' do
      before do
        organization.add_user(user)
        suspended_organization.add_user(user)
        space.add_developer(user)
        space_whose_org_is_suspended.add_developer(user)
      end

      it 'only returns the spaces for an active org' do
        membership = Membership.new(user)
        expect(membership.developed_spaces).not_to include space_whose_org_is_suspended
        expect(membership.developed_spaces).not_to include space_that_user_doesnt_develop_in
        expect(membership.developed_spaces).not_to include space_in_some_other_org
        expect(membership.developed_spaces).to include space
      end
    end
  end
end
