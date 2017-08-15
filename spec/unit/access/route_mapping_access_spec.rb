require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteMappingModelAccess, type: :access do
    subject(:access) { RouteMappingModelAccess.new(Security::AccessContext.new) }
    let(:scopes) { ['cloud_controller.read', 'cloud_controller.write'] }

    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }
    let(:process) { VCAP::CloudController::ProcessModelFactory.make(space: space) }
    let(:route) { VCAP::CloudController::Route.make(domain: domain, space: space) }
    let(:object) { VCAP::CloudController::RouteMappingModel.make(route: route, app: process) }

    before { set_current_user(user, scopes: scopes) }

    it_behaves_like :admin_read_only_access

    context 'admin' do
      include_context :admin_setup

      it_behaves_like :full_access
    end

    context 'space developer' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end

      it_behaves_like :full_access

      context 'when the organization is suspended' do
        before do
          org.status = 'suspended'
          org.save
        end

        it_behaves_like :read_only_access
      end
    end
  end
end
