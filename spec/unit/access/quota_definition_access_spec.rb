require 'spec_helper'

module VCAP::CloudController
  RSpec.describe QuotaDefinitionAccess, type: :access do
    subject(:access) { QuotaDefinitionAccess.new(Security::AccessContext.new) }
    let(:scopes) { ['cloud_controller.read', 'cloud_controller.write'] }

    let(:user) { create(:user) }
    let(:object) { create(:quota_definition) }

    before { set_current_user(user, scopes:) }

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
      let(:scopes) { [] }

      it_behaves_like 'no access'
    end
  end
end
