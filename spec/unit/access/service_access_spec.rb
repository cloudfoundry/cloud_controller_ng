require 'spec_helper'

module VCAP::CloudController
  describe ServiceAccess, type: :access do
    before do
      token = {'scope' => 'cloud_controller.read cloud_controller.write'}
      allow(VCAP::CloudController::SecurityContext).to receive(:token).and_return(token)
    end

    subject(:access) { ServiceAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let!(:service_plan) { VCAP::CloudController::ServicePlan.make(:service => object) }
    let(:object) { VCAP::CloudController::Service.make }

    it_should_behave_like :admin_full_access

    context 'for a logged in user' do
      it_behaves_like :read_only
    end

    context 'a user that is not logged in' do
      let(:user) { nil }
      let(:roles) { double(:roles, :admin? => false, :none? => true, :present? => false) }
      it_behaves_like :read_only
    end

    context 'any user using client without cloud_controller.read' do
      before do
        token = { 'scope' => ''}
        allow(VCAP::CloudController::SecurityContext).to receive(:token).and_return(token)
      end

      it_behaves_like :no_access
    end
  end
end
