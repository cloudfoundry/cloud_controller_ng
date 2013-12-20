require 'spec_helper'

module VCAP::CloudController
  describe AppUsageEventAccess, type: :access do
    subject(:access) { AppUsageEventAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:object) { VCAP::CloudController::AppUsageEvent.make }

    it_should_behave_like :admin_full_access

    context 'a user that is not an admin (defensive)' do
      it_behaves_like :no_access
      it { should_not be_able_to :index, VCAP::CloudController::AppUsageEvent }
      it { should_not be_able_to :reset, VCAP::CloudController::AppUsageEvent }
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:roles) { double(:roles, :admin? => false, :none? => true, :present? => false) }
      it_behaves_like :no_access
      it { should_not be_able_to :index, VCAP::CloudController::AppUsageEvent }
      it { should_not be_able_to :reset, VCAP::CloudController::AppUsageEvent }
    end
  end
end
