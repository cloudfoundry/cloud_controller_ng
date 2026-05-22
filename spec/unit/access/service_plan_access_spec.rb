require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServicePlanAccess, type: :access do
    subject(:access) { ServicePlanAccess.new(Security::AccessContext.new) }
    let(:user) { create(:user) }
    let(:service) { create(:service) }
    let(:object) { create(:service_plan, service:) }

    before { set_current_user(user) }

    it_behaves_like 'admin full access'
    it_behaves_like 'admin read only access'

    context 'for a logged in user (defensive)' do
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
