
require 'spec_helper'

describe UserSummaryPresenter do
  describe "#to_hash" do
    let(:org) { VCAP::CloudController::Models::Organization.make }
    let(:managed_org) { VCAP::CloudController::Models::Organization.make }
    let(:space) { VCAP::CloudController::Models::Space.make(organization: org) }
    let(:managed_space) { VCAP::CloudController::Models::Space.make(organization: managed_org) }
    let(:user) do
      u = make_developer_for_space(space)
      u.add_organization(managed_org)
      managed_space.add_manager(u)
      u
    end

    subject { UserSummaryPresenter.new(user) }

    it "creates a valid JSON" do
      subject.to_hash.should eq({
        metadata: {
          guid: user.guid,
          created_at: user.created_at.to_s,
          updated_at: user.updated_at.to_s
        },
        entity: {
          organizations: [OrganizationPresenter.new(org).to_hash, OrganizationPresenter.new(managed_org).to_hash],
          managed_organizations: [OrganizationPresenter.new(managed_org).to_hash],
          spaces: [SpacePresenter.new(space).to_hash],
          managed_spaces: [SpacePresenter.new(managed_space).to_hash]
        }
      })
    end
  end
end
