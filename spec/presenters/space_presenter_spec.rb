require 'spec_helper'

describe SpacePresenter do
  describe "#to_hash" do
    let(:space) { VCAP::CloudController::Models::Space.make }
    subject { SpacePresenter.new(space) }

    it "creates a valid JSON" do
      subject.to_hash.should eq({
        :metadata => {
          :guid => space.guid,
          :created_at => space.created_at.to_s,
          :updated_at => space.updated_at.to_s
        },
        :entity => {
          :name => space.name
        }
      })
    end
  end
end
