require 'spec_helper'

module VCAP::CloudController::Models
  describe AppEventAccess, type: :access do
    subject(:access) { AppEventAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::Models::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:org) { VCAP::CloudController::Models::Organization.make }
    let(:space) { VCAP::CloudController::Models::Space.make(:organization => org) }
    let(:app) { VCAP::CloudController::Models::App.make(:space => space) }
    let(:object) { VCAP::CloudController::Models::AppEvent.make(:app => app) }

    it_should_behave_like :admin_full_access

    context 'organization manager' do
      before { org.add_manager(user) }
      it_behaves_like :read_only
    end

    context 'organization user' do
      before { org.add_user(user) }
      it_behaves_like :read_only
    end
  end
end