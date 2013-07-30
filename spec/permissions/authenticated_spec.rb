require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Permissions::Authenticated do
    let(:obj)         { Models::Organization.make }
    let(:granted)     { Models::User.make }
    let(:not_granted) { nil }

    it_behaves_like "a cf permission", "authenticated"
  end
end
