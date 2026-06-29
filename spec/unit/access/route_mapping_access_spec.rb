require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteMappingModelAccess, type: :access do
    subject(:access) { RouteMappingModelAccess.new(Security::AccessContext.new) }
    let(:scopes) { ['cloud_controller.read', 'cloud_controller.write'] }

    let(:user) { create(:user) }
    let(:org) { create(:organization) }
    let(:space) { create(:space, organization: org) }
    let(:domain) { create(:private_domain, owning_organization: org) }
    let(:process) { VCAP::CloudController::ProcessModelFactory.make(space:) }
    let(:route) { create(:route, domain:, space:) }
    let(:object) { create(:route_mapping_model, route: route, app: process) }

    before { set_current_user(user, scopes:) }

    it_behaves_like 'admin read only access'

    context 'admin' do
      include_context 'admin setup'

      it_behaves_like 'full access'
    end

    context 'space developer' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end

      it_behaves_like 'full access'

      context 'when the organization is suspended' do
        before do
          org.status = 'suspended'
          org.save
        end

        it_behaves_like 'read only access'
      end
    end
  end
end
