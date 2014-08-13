require 'spec_helper'

module VCAP::CloudController
  describe ServiceUsageEventAccess, type: :access do
    subject(:access) { ServiceUsageEventAccess.new(Security::AccessContext.new) }
    let(:token) {{ 'scope' => ['cloud_controller.read', 'cloud_controller.write'] }}
    let(:user) { VCAP::CloudController::User.make }
    let(:object) { VCAP::CloudController::ServiceUsageEvent.make }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'an admin' do
      include_context :admin_setup
      it_behaves_like :full_access
      it { is_expected.to allow_op_on_object :reset, VCAP::CloudController::ServiceUsageEvent }
    end

    context 'a user that is not an admin (defensive)' do
      it_behaves_like :no_access
      it { is_expected.not_to allow_op_on_object :index, VCAP::CloudController::ServiceUsageEvent }
      it { is_expected.not_to allow_op_on_object :reset, VCAP::CloudController::ServiceUsageEvent }
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      it_behaves_like :no_access
      it { is_expected.not_to allow_op_on_object :index, VCAP::CloudController::ServiceUsageEvent }
      it { is_expected.not_to allow_op_on_object :reset, VCAP::CloudController::ServiceUsageEvent }
    end
  end
end
