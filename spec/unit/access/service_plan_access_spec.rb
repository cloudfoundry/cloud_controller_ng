require 'spec_helper'

module VCAP::CloudController
  describe ServicePlanAccess, type: :access do
    before do
      token = {'scope' => 'cloud_controller.read cloud_controller.write'}
      VCAP::CloudController::SecurityContext.stub(:token).and_return(token)
    end

    subject(:access) { ServicePlanAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:service) { VCAP::CloudController::Service.make }

    let(:object) { VCAP::CloudController::ServicePlan.make(:service => service) }

    it_should_behave_like :admin_full_access

    context 'for a logged in user (defensive)' do
      it_behaves_like :read_only
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:roles) { double(:roles, :admin? => false, :none? => true, :present? => false) }
      it_behaves_like :no_access
    end

    context 'any user using client without cloud_controller.read' do
      before do
        token = { 'scope' => ''}
        VCAP::CloudController::SecurityContext.stub(:token).and_return(token)
      end

      it_behaves_like :no_access
    end
  end
end
