require 'spec_helper'

module VCAP::CloudController
  RSpec.describe StackAccess, type: :access do
    subject(:access) { StackAccess.new(Security::AccessContext.new) }
    let(:user) { VCAP::CloudController::User.make }
    let(:object) { VCAP::CloudController::Stack.make }

    before { set_current_user(user) }

    it_behaves_like 'admin full access'
    it_behaves_like 'admin read only access'

    context 'a logged in user' do
      it_behaves_like 'read only access'
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }

      it_behaves_like 'no access'
    end

    context 'any user using client without cloud_controller.read' do
      before { set_current_user(user, scopes: []) }

      it_behaves_like 'no access'
    end
  end
end
