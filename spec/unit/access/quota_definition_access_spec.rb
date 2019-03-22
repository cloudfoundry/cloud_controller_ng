require 'spec_helper'

module VCAP::CloudController
  RSpec.describe QuotaDefinitionAccess, type: :access do
    subject(:access) { QuotaDefinitionAccess.new(Security::AccessContext.new) }
    let(:scopes) { ['cloud_controller.read', 'cloud_controller.write'] }

    let(:user) { VCAP::CloudController::User.make }
    let(:object) { VCAP::CloudController::QuotaDefinition.make }

    before { set_current_user(user, scopes: scopes) }

    it_behaves_like :admin_full_access
    it_behaves_like :admin_read_only_access

    context 'a logged in user' do
      it_behaves_like :read_only_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      it_behaves_like :no_access
    end

    context 'any user using client without cloud_controller.read' do
      let(:scopes) { [] }

      it_behaves_like :no_access
    end
  end
end
