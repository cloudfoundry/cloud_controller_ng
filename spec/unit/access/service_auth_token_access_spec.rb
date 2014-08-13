require 'spec_helper'

module VCAP::CloudController
  describe ServiceAuthTokenAccess, type: :access do
    subject(:access) { ServiceAuthTokenAccess.new(Security::AccessContext.new) }
    let(:token) {{ 'scope' => ['cloud_controller.read', 'cloud_controller.write'] }}

    let(:user) { VCAP::CloudController::User.make }
    let(:service) { VCAP::CloudController::Service.make }
    let(:object) { VCAP::CloudController::ServiceAuthToken.make(:service) }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    it_should_behave_like :admin_full_access

    context 'for a logged in user (defensive)' do
      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      it_behaves_like :no_access
    end
  end
end
