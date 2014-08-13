require 'spec_helper'

module VCAP::CloudController
  describe SharedDomainAccess, type: :access do
    subject(:access) { SharedDomainAccess.new(Security::AccessContext.new) }
    let(:token) {{ 'scope' => ['cloud_controller.read', 'cloud_controller.write'] }}

    let(:user) { VCAP::CloudController::User.make }
    let(:object) { VCAP::CloudController::SharedDomain.new }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    it_should_behave_like :admin_full_access

    context 'a logged in user' do
      it_behaves_like :read_only
    end

    context 'any user using client without cloud_controller.read' do
      let(:token) {{ 'scope' => [] }}
      it_behaves_like :no_access
    end
  end
end
