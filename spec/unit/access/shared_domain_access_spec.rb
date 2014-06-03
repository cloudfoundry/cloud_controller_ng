require 'spec_helper'

module VCAP::CloudController
  describe SharedDomainAccess, type: :access do
    before do
      token = {'scope' => scope }
      VCAP::CloudController::SecurityContext.stub(:token).and_return(token)
    end

    subject(:access) { SharedDomainAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:object) { VCAP::CloudController::SharedDomain.new }
    let(:scope) { 'cloud_controller.read cloud_controller.write cloud_controller.admin' }

    it_should_behave_like :admin_full_access

    context 'a logged in user' do
      let(:scope) { 'cloud_controller.read cloud_controller.write' }
      it_behaves_like :read_only
    end

    context 'any user using client without cloud_controller.read' do
      let(:scope) { '' }
      it_behaves_like :no_access
    end
  end
end
