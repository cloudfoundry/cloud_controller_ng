require 'spec_helper'

module VCAP::CloudController
  describe OrganizationAccess, type: :access do
    before do
      token = {'scope' => 'cloud_controller.read cloud_controller.write'}
      allow(VCAP::CloudController::SecurityContext).to receive(:token).and_return(token)
      FeatureFlag.make(name: 'user_org_creation', enabled: false)
    end

    subject(:access) { OrganizationAccess.new(double(:context, user: user, roles: roles)) }
    let(:object) { VCAP::CloudController::Organization.make }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }

    it_should_behave_like :admin_full_access

    context 'an admin of the organization' do
      include_context :admin_setup

      context 'changing the name' do
        before { object.name = 'my new name' }
        it { is_expected.to allow_op_on_object :update, object }
      end

      context 'with a suspended organization' do
        before { object.set(status: 'suspended') }
        it_behaves_like :full_access
      end
    end

    context 'a user in the organization' do
      before { object.add_user(user) }
      it_behaves_like :read_only
    end

    context 'a user not in the organization' do
      context 'when the user_org_creation feature flag is not enabled' do
        it_behaves_like :no_access
      end

      context 'when the user_org_creation feature flag is enabled' do
        before do
          FeatureFlag.find(name: 'user_org_creation').update(enabled: true)
        end

        it { is_expected.to allow_op_on_object :create, object }
        it { is_expected.not_to allow_op_on_object :read, object }
        it { is_expected.not_to allow_op_on_object :update, object }
        it { is_expected.not_to allow_op_on_object :delete, object }
      end
    end

    context 'a billing manager for the organization' do
      before { object.add_billing_manager(user) }
      it_behaves_like :read_only
    end

    context 'a manager for the organization' do
      before { object.add_manager(user) }

      context 'with an active organization' do
        it { is_expected.not_to allow_op_on_object :create, object }
        it { is_expected.to allow_op_on_object :read, object }
        it { is_expected.to allow_op_on_object :update, object }
        it { is_expected.not_to allow_op_on_object :delete, object }
      end

      context 'changing the name' do
        before { object.name = 'my new name' }
        it { is_expected.to allow_op_on_object :update, object }
      end

      context 'with a suspended organization' do
        before { object.set(status: 'suspended') }
        it_behaves_like :read_only
      end
    end

    context 'an auditor for the organization' do
      before { object.add_auditor(user) }
      it_behaves_like :read_only
    end

    context 'any user using client without cloud_controller.write' do
      before do
        token = { 'scope' => 'cloud_controller.read'}
        allow(VCAP::CloudController::SecurityContext).to receive(:token).and_return(token)
        object.add_user(user)
        object.add_manager(user)
        object.add_billing_manager(user)
        object.add_auditor(user)
      end

      it_behaves_like :read_only
    end

    context 'any user using client without cloud_controller.read' do
      before do
        token = { 'scope' => ''}
        allow(VCAP::CloudController::SecurityContext).to receive(:token).and_return(token)
        object.add_user(user)
        object.add_manager(user)
        object.add_billing_manager(user)
        object.add_auditor(user)
      end

      it_behaves_like :no_access
    end
  end
end
