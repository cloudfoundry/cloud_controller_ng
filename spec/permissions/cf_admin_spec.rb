require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Permissions::CFAdmin do
    let(:obj)         { Models::Organization.make }
    let(:not_granted) { Models::User.make }
    let(:granted)     { Models::User.make(:admin => true) }

    it_behaves_like "a cf permission", "admin"
  end
end
