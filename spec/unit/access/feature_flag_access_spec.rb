require 'spec_helper'

module VCAP::CloudController
  describe FeatureFlagAccess, type: :access do
    subject(:access) { FeatureFlagAccess.new(Security::AccessContext.new) }
    let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, admin?: false, none?: false, present?: true) }
    let(:object) { VCAP::CloudController::FeatureFlag.make }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    it_behaves_like :admin_full_access

    context 'a user that has cloud_controller.read' do
      let(:token) { { 'scope' => ['cloud_controller.read']} }

      it_behaves_like :read_only
    end

    context 'a user that does not have cloud_controller.read' do
      let(:token) { { 'scope' => []} }

      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:token) { { 'scope' => []} }
      let(:user) { nil }
      let(:roles) { double(:roles, admin?: false, none?: true, present?: false) }

      it_behaves_like :no_access
      it { is_expected.not_to allow_op_on_object :index, VCAP::CloudController::FeatureFlag }
    end
  end
end
