require 'spec_helper'

module VCAP::CloudController
  describe QuotaDefinitionAccess, type: :access do
    subject(:access) { QuotaDefinitionAccess.new(Security::AccessContext.new) }
    let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }

    let(:user) { VCAP::CloudController::User.make }
    let(:object) { VCAP::CloudController::QuotaDefinition.make }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    it_should_behave_like :admin_full_access

    context 'a logged in user' do
      it_behaves_like :read_only_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      it_behaves_like :no_access
    end

    context 'any user using client without cloud_controller.read' do
      let(:token) { { 'scope' => [] } }

      it_behaves_like :no_access
    end
  end
end
