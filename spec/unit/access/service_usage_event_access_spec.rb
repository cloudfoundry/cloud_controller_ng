require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceUsageEventAccess, type: :access do
    subject(:access) { ServiceUsageEventAccess.new(Security::AccessContext.new) }
    let(:user) { VCAP::CloudController::User.make }
    let(:object) { VCAP::CloudController::ServiceUsageEvent.make }

    before { set_current_user(user) }

    it_behaves_like 'admin read only access'

    context 'an admin' do
      include_context 'admin setup'

      it_behaves_like 'full access'
      it { is_expected.to allow_op_on_object :reset, VCAP::CloudController::ServiceUsageEvent }
    end

    context 'a global auditor' do
      it_behaves_like 'global auditor access'
    end

    context 'a user that is not an admin (defensive)' do
      it_behaves_like 'no access'

      it { is_expected.not_to allow_op_on_object :index, VCAP::CloudController::ServiceUsageEvent }
      it { is_expected.not_to allow_op_on_object :reset, VCAP::CloudController::ServiceUsageEvent }
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }

      it_behaves_like 'no access'
      it { is_expected.not_to allow_op_on_object :index, VCAP::CloudController::ServiceUsageEvent }
      it { is_expected.not_to allow_op_on_object :reset, VCAP::CloudController::ServiceUsageEvent }
    end
  end
end
