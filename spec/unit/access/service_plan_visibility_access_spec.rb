require 'spec_helper'

module VCAP::CloudController
  describe ServicePlanVisibilityAccess, type: :access do
    before do
      token = {'scope' => 'cloud_controller.read cloud_controller.write'}
      VCAP::CloudController::SecurityContext.stub(:token).and_return(token)
    end

    subject(:access) { ServicePlanVisibilityAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:service) { VCAP::CloudController::Service.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(:service => service) }

    let(:object) { VCAP::CloudController::ServicePlanVisibility.make(:organization => org, :service_plan => service_plan) }

    it_should_behave_like :admin_full_access

    context 'for a logged in user (defensive)' do
      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:roles) { double(:roles, :admin? => false, :none? => true, :present? => false) }
      it_behaves_like :no_access
    end

    context 'organization manager (defensive)' do
      before { org.add_manager(user) }
      it_behaves_like :no_access
    end

    context 'organization auditor (defensive)' do
      before { org.add_auditor(user) }
      it_behaves_like :no_access
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }
      it_behaves_like :no_access
    end
  end
end
