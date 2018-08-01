require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SharedDomainAccess, type: :access do
    subject(:access) { SharedDomainAccess.new(Security::AccessContext.new) }

    let(:user) { VCAP::CloudController::User.make }
    let(:object) { VCAP::CloudController::SharedDomain.new }

    before { set_current_user(user) }

    it_behaves_like :admin_full_access
    it_behaves_like :admin_read_only_access

    context 'a logged in user' do
      it_behaves_like :read_only_access
    end

    context 'any user using client without cloud_controller.read' do
      before { set_current_user(user, scopes: []) }

      it_behaves_like :no_access
    end
  end
end
