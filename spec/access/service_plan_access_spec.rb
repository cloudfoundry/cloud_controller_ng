require 'spec_helper'

module VCAP::CloudController::Models
  describe ServicePlanAccess, type: :access do
    subject(:access) { ServicePlanAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::Models::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:service) { VCAP::CloudController::Models::Service.make }

    let(:object) { VCAP::CloudController::Models::ServicePlan.make(:service => service) }

    it_should_behave_like :admin_full_access

    context 'for a logged in user (defensive)' do
      it_behaves_like :read_only
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:roles) { double(:roles, :admin? => false, :none? => true, :present? => false) }
      it_behaves_like :no_access
    end
  end
end