require "spec_helper"

describe MaxRoutesPolicy do
  describe "#allow_more_routes?" do
    let(:policy) { MaxRoutesPolicy.new(organization) }
    let(:organization) do
      quota_definition = VCAP::CloudController::QuotaDefinition.make(total_routes: 4)
      VCAP::CloudController::Organization.make(quota_definition: quota_definition)
    end
    let!(:routes) do
      space = VCAP::CloudController::Space.make(organization: organization)
      2.times { VCAP::CloudController::Route.make(space: space) }
    end

    subject { policy.allow_more_routes?(requested_routes) }

    context "when requested exceeds the total allowed routes" do
      let(:requested_routes) { 3 }
      it { should be_false }
    end

    context "when requested equals the total allowed routes" do
      let(:requested_routes) { 2 }
      it { should be_true }
    end

    context "when requested less than the total allowed routes" do
      let(:requested_routes) { 1 }
      it { should be_true }
    end
  end
end
