require "spec_helper"

describe OrganizationRoutes do
  let(:organization) { VCAP::CloudController::Organization.make }

  subject(:organization_routes) { OrganizationRoutes.new(organization) }

  describe "#count" do
    context "when there is no spaces" do
      its(:count) { should eq 0 }
    end

    context "when there are spaces" do
      let!(:space) { VCAP::CloudController::Space.make(organization: organization) }

      context "and there no routes" do
        its(:count) { should eq 0 }
      end

      context "and there are multiple routes" do
        let!(:routes) { 2.times { VCAP::CloudController::Route.make(space: space) } }
        its(:count) { should eq 2 }
      end

      context "and there are multiple routes" do
        let(:space_2) { VCAP::CloudController::Space.make(organization: organization) }
        let!(:routes) do
          2.times { VCAP::CloudController::Route.make(space: space) }
          VCAP::CloudController::Route.make(space: space_2)
        end
        its(:count) { should eq 3 }
      end

      context "and there is a route belonging to different organization" do
        let!(:route) { VCAP::CloudController::Route.make }
        its(:count) { should eq 0 }
      end
    end
  end
end
