require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServicePlanVisibilityAccess, type: :access do
    subject(:access) { ServicePlanVisibilityAccess.new(Security::AccessContext.new) }

    let(:user) { create(:user) }
    let(:service) { create(:service) }
    let(:org) { create(:organization) }
    let(:service_plan) { create(:service_plan, service: service, public: false) }

    let(:object) { create(:service_plan_visibility, organization: org, service_plan: service_plan) }

    before { set_current_user(user) }

    it_behaves_like 'admin full access'
    it_behaves_like 'admin read only access'

    context 'for a logged in user (defensive)' do
      it_behaves_like 'no access'
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }

      it_behaves_like 'no access'
    end

    context 'organization manager (defensive)' do
      before { org.add_manager(user) }

      it_behaves_like 'no access'
    end

    context 'organization auditor (defensive)' do
      before { org.add_auditor(user) }

      it_behaves_like 'no access'
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }

      it_behaves_like 'no access'
    end
  end
end
