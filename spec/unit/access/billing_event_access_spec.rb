require 'spec_helper'

module VCAP::CloudController
  describe BillingEventAccess, type: :access do
    subject(:access) { BillingEventAccess.new(Security::AccessContext.new) }
    let(:token) {{ 'scope' => ['cloud_controller.read', 'cloud_controller.write'] }}

    before do
      TestConfig.override({ :billing_event_writing_enabled => true })
    end

    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make(billing_enabled: true) }
    let(:space) { VCAP::CloudController::Space.make(:organization => org) }
    let(:app) { VCAP::CloudController::AppFactory.make(:space => space) }
    let(:object) { VCAP::CloudController::AppStartEvent.create_from_app(app) }

    it_should_behave_like :admin_full_access

    context 'organization manager (defensive)' do
      before { org.add_manager(user) }
      it_behaves_like :no_access
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }
      it_behaves_like :no_access
    end

    context 'user in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_user(user)
      end

      it_behaves_like :no_access
    end

    context 'manager in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_manager(user)
      end

      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      it_behaves_like :no_access
    end
  end
end
