require 'spec_helper'

module VCAP::CloudController::Models
  describe ServiceBindingAccess, type: :access do
    subject(:access) { ServiceBindingAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::Models::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:service) { VCAP::CloudController::Models::Service.make }
    let(:org) { VCAP::CloudController::Models::Organization.make }
    let(:space) { VCAP::CloudController::Models::Space.make(:organization => org) }
    let(:app) { VCAP::CloudController::Models::App.make(:space => space) }
    let(:service_instance) { VCAP::CloudController::Models::ManagedServiceInstance.make(:space => space) }

    let(:object) { VCAP::CloudController::Models::ServiceBinding.make(:app => app, :service_instance => service_instance) }

    it_should_behave_like :admin_full_access

    context 'for a logged in user (defensive)' do
      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:roles) { double(:roles, :admin? => false, :none? => true, :present? => false) }
      it_behaves_like :no_access
    end

    context 'organization manager (defensive)' do
      before { org.add_manager(user) }
      it_behaves_like :no_access
    end

    context 'organization auditor (defensive)' do
      before { org.add_auditor(user) }
      it_behaves_like :no_access
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }
      it_behaves_like :no_access
    end

    context 'space auditor' do
      before do
        org.add_user(user)
        space.add_auditor(user)
      end

      it_behaves_like :read_only
    end

    context 'space manager (defensive)' do
      before do
        org.add_user(user)
        space.add_manager(user)
      end

      it_behaves_like :no_access
    end

    context 'space developer' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end

      it { should be_able_to :create, object }
      it { should be_able_to :read, object }
      it { should_not be_able_to :update, object }
      it { should be_able_to :delete, object }
    end
  end
end