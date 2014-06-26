require 'spec_helper'

module VCAP::CloudController
  describe AppAccess, type: :access do
    before do
      token = {'scope' => 'cloud_controller.read cloud_controller.write'}
      allow(VCAP::CloudController::SecurityContext).to receive(:token).and_return(token)
    end

    subject(:access) { AppAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(:organization => org) }
    let(:object) { VCAP::CloudController::AppFactory.make(:space => space) }

    context 'admin' do
      before do
        allow(roles).to receive(:admin?).and_return(true)
      end

      it_should_behave_like :admin_full_access

      it 'allows user to :read_env' do
        expect(subject).to allow_op_on_object(:read_env, object)
      end
    end

    context 'space developer' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end
      it_behaves_like :full_access

      it 'allows user to :read_env' do
        expect(subject).to allow_op_on_object(:read_env, object)
      end

      context 'when the organization is suspended' do
        before { allow(object).to receive(:in_suspended_org?).and_return(true) }
        it_behaves_like :read_only
      end

    end

    context 'organization manager' do
      before { org.add_manager(user) }
      it_behaves_like :read_only

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'organization user' do
      before { org.add_user(user) }
      it_behaves_like :no_access

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'organization auditor' do
      before { org.add_auditor(user) }
      it_behaves_like :no_access

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'billing manager' do
      before { org.add_billing_manager(user) }
      it_behaves_like :no_access

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'space manager' do
      before do
        org.add_user(user)
        space.add_manager(user)
      end
      it_behaves_like :read_only

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'space auditor' do
      before do
        org.add_user(user)
        space.add_auditor(user)
      end
      it_behaves_like :read_only

      it 'does not allow user to :read_env' do
        expect(subject).not_to allow_op_on_object(:read_env, object)
      end
    end

    context 'any user using client without cloud_controller.write' do
      before do
        token = { 'scope' => 'cloud_controller.read'}
        allow(VCAP::CloudController::SecurityContext).to receive(:token).and_return(token)
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
        allow(VCAP::CloudController::SecurityContext).to receive(:token).and_return(token)
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
