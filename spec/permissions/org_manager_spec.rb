require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Permissions::OrgManager do
    let(:obj)         { Models::Organization.make }
    let(:not_granted) { Models::User.make }
    let(:granted) do
      manager = Models::User.make
      obj.add_manager(manager)
    end

    it_behaves_like "a cf permission", "org manager"
  end
end
