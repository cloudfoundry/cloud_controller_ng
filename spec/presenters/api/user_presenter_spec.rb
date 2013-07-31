require 'spec_helper'

describe UserPresenter do
  describe "#to_hash" do
    let(:user) { VCAP::CloudController::Models::User.make(admin: true) }
    subject { UserPresenter.new(user) }

    it "creates a valid JSON" do
      subject.to_hash.should eq({
        metadata: {
            guid: user.guid,
            created_at: user.created_at.to_s,
            updated_at: user.updated_at.to_s
        },
        entity: {
            admin: true,
            active: false,
            default_space_guid: nil
        }
      })
    end
  end
end
