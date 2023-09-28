require 'spec_helper'

module VCAP::CloudController
  RSpec.describe FeatureFlagAccess, type: :access do
    subject(:access) { FeatureFlagAccess.new(Security::AccessContext.new) }
    let(:user) { VCAP::CloudController::User.make }
    let(:object) { VCAP::CloudController::FeatureFlag.make }

    it_behaves_like 'admin full access'
    it_behaves_like 'admin read only access'

    context 'a user that has cloud_controller.read' do
      before { set_current_user(user, scopes: ['cloud_controller.read']) }

      it_behaves_like 'read only access'
    end

    context 'a user that does not have cloud_controller.read' do
      before { set_current_user(user, scopes: ['cloud_controller.write']) }

      it_behaves_like 'no access'
    end

    context 'a user that isnt logged in (defensive)' do
      it_behaves_like 'no access'

      it { is_expected.not_to allow_op_on_object :index, VCAP::CloudController::FeatureFlag }
    end
  end
end
