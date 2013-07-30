require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Permissions::SpaceManager do
    let(:obj)         { Models::Space.make }
    let(:not_granted) { Models::User.make }
    let(:granted) do
      manager = make_user_for_space(obj)
      obj.add_manager(manager)
    end

    it_behaves_like "a cf permission", "app space manager"
  end
end
