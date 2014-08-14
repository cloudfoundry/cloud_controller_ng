require 'spec_helper'

module VCAP::CloudController
  describe SpaceAccess, type: :access do
    subject(:access) { SpaceAccess.new(Security::AccessContext.new) }
    let(:token) {{ 'scope' => ['cloud_controller.read', 'cloud_controller.write'] }}
    let(:org) { VCAP::CloudController::Organization.make }
    let(:object) { VCAP::CloudController::Space.make(organization: org) }

    let(:user) { VCAP::CloudController::User.make }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    it_should_behave_like :admin_full_access

    context 'as an organization manager' do
      before { org.add_manager(user) }
      it_behaves_like :full_access

      context 'when the organization is suspended' do
        before { object.organization.status = 'suspended' }
        it_behaves_like :read_only
      end
    end

    context 'as a space manager' do
      before do
        org.add_user(user)
        object.add_manager(user)
      end

      it { is_expected.not_to allow_op_on_object :create, object }
      it { is_expected.to allow_op_on_object :read, object }
      it { is_expected.to allow_op_on_object :read_for_update, object }
      it { is_expected.to allow_op_on_object :update, object }
      it { is_expected.not_to allow_op_on_object :delete, object }

      context 'when the organization is suspended' do
        before { object.organization.status = 'suspended' }

        it_behaves_like :read_only
      end
    end

    context 'as a space developer' do
      before do
        org.add_user(user)
        object.add_developer(user)
      end

      it_behaves_like :read_only
    end

    context 'as a space auditor' do
      before do
        org.add_user(user)
        object.add_auditor(user)
      end

      it_behaves_like :read_only
    end

    context 'as an organization auditor (defensive)' do
      before { org.add_auditor(user) }
      it_behaves_like :no_access
    end

    context 'as an organization billing manager (defensive)' do
      before { org.add_billing_manager(user) }
      it_behaves_like :no_access
    end

    context 'as an organization user (defensive)' do
      before { org.add_user(user) }
      it_behaves_like :no_access
    end

    context 'as a user in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_user(user)
      end

      it_behaves_like :no_access
    end

    context 'as a manager in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_manager(user)
      end

      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:roles) { double(:roles, :admin? => false, :none? => true, :present? => false) }
      it_behaves_like :no_access
    end

    context 'any user using client without cloud_controller.write' do
      let(:token) {{'scope' => ['cloud_controller.read']}}

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        object.add_manager(user)
        object.add_developer(user)
        object.add_auditor(user)
      end

      it_behaves_like :read_only
    end

    context 'any user using client without cloud_controller.read' do
      let(:token) {{'scope' => []}}

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        object.add_manager(user)
        object.add_developer(user)
        object.add_auditor(user)
      end

      it_behaves_like :no_access
    end
  end
end
