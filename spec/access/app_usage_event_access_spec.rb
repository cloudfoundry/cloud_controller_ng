require 'spec_helper'

module VCAP::CloudController
  describe AppUsageEventAccess, type: :access do
    before do
      token = {'scope' => 'cloud_controller.read cloud_controller.write'}
      VCAP::CloudController::SecurityContext.stub(:token).and_return(token)
    end

    subject(:access) { AppUsageEventAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:object) { VCAP::CloudController::AppUsageEvent.make }

    context 'an admin' do
      include_context :admin_setup
      it_behaves_like :full_access
      it { should allow_op_on_object :reset, VCAP::CloudController::AppUsageEvent }
    end

    context 'a user that is not an admin (defensive)' do
      it_behaves_like :no_access
      it { should_not allow_op_on_object :index, VCAP::CloudController::AppUsageEvent }
      it { should_not allow_op_on_object :reset, VCAP::CloudController::AppUsageEvent }
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:roles) { double(:roles, :admin? => false, :none? => true, :present? => false) }
      it_behaves_like :no_access
      it { should_not allow_op_on_object :index, VCAP::CloudController::AppUsageEvent }
      it { should_not allow_op_on_object :reset, VCAP::CloudController::AppUsageEvent }
    end
  end
end
