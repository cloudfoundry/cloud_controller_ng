require 'spec_helper'

module VCAP::CloudController
  describe ServiceBindingAccess, type: :access do
    before do
      token = {'scope' => 'cloud_controller.read cloud_controller.write'}
      VCAP::CloudController::SecurityContext.stub(:token).and_return(token)
    end

    subject(:access) { ServiceBindingAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:service) { VCAP::CloudController::Service.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(:organization => org) }
    let(:app) { VCAP::CloudController::AppFactory.make(:space => space) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(:space => space) }

    let(:object) { VCAP::CloudController::ServiceBinding.make(:app => app, :service_instance => service_instance) }

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

    context 'organization billing manager (defensive)' do
      before { org.add_billing_manager(user) }
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

      context 'when the organization is suspended' do
        before { allow(object).to receive(:in_suspended_org?).and_return(true) }
        it_behaves_like :read_only
      end
    end

    context 'any user using client without cloud_controller.write' do
      before do
        token = { 'scope' => 'cloud_controller.read'}
        VCAP::CloudController::SecurityContext.stub(:token).and_return(token)
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        space.add_manager(user)
        space.add_developer(user)
        space.add_auditor(user)
      end

      it_behaves_like :read_only
    end

    context 'any user using client without cloud_controller.read' do
      before do
        token = { 'scope' => ''}
        VCAP::CloudController::SecurityContext.stub(:token).and_return(token)
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        space.add_manager(user)
        space.add_developer(user)
        space.add_auditor(user)
      end

      it_behaves_like :no_access
    end
  end
end
