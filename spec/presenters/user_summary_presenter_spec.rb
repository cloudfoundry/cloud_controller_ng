require 'spec_helper'

describe UserSummaryPresenter do
  describe "#to_hash" do
    let(:org) { VCAP::CloudController::Models::Organization.make }
    let(:space) { VCAP::CloudController::Models::Space.make(organization: org) }
    let(:user) { make_user_for_space(space) }

    subject { UserSummaryPresenter.new(user) }

    it "creates a valid JSON" do
      subject.to_hash.should eq({
        metadata: {
          guid: user.guid,
          created_at: user.created_at.to_s,
          updated_at: user.updated_at.to_s
        },
        entity: {
          organizations: [OrganizationPresenter.new(org).to_hash]
        }
      })
    end
  end
end
