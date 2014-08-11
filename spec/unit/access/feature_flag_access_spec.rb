require 'spec_helper'

module VCAP::CloudController
  describe FeatureFlagAccess, type: :access do
    let(:token) { { 'scope' => 'cloud_controller.read cloud_controller.write' } }
    before do
      allow(VCAP::CloudController::SecurityContext).to receive(:token).and_return(token)
    end

    subject(:access) { FeatureFlagAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, admin?: false, none?: false, present?: true) }
    let(:object) { VCAP::CloudController::FeatureFlag.make }

    context 'an admin' do
      include_context :admin_setup
      it_behaves_like :full_access
    end

    context 'a user that has cloud_controller.read' do
      let(:token) { { 'scope' => 'cloud_controller.read'} }

      it_behaves_like :read_only
    end

    context 'a user that does not have cloud_controller.read' do
      let(:token) { { 'scope' => ''} }

      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:token) { { 'scope' => ''} }
      let(:user) { nil }
      let(:roles) { double(:roles, admin?: false, none?: true, present?: false) }

      it_behaves_like :no_access
      it { is_expected.not_to allow_op_on_object :index, VCAP::CloudController::FeatureFlag }
    end
  end
end
