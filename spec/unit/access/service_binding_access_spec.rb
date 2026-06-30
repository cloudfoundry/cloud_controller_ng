require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceBindingAccess, type: :access do
    subject(:access) { ServiceBindingAccess.new(Security::AccessContext.new) }
    let(:scopes) { ['cloud_controller.read', 'cloud_controller.write'] }

    let(:user) { create(:user) }
    let(:service) { create(:service) }
    let(:org) { create(:organization) }
    let(:space) { create(:space, organization: org) }
    let(:app) { create(:app_model, space:) }
    let(:service_instance) { create(:managed_service_instance) }

    let(:object) do
      service_instance.add_shared_space(app.space)
      create(:service_binding, service_instance:, app:)
    end

    before { set_current_user(user, scopes:) }

    describe 'admin' do
      context 'readonly' do
        include_context 'admin read only setup'

        it { is_expected.to allow_op_on_object :read, object }
        it { is_expected.not_to allow_op_on_object :read_for_update, object }
        it { is_expected.not_to allow_op_on_object :update, object }
        it { is_expected.to allow_op_on_object :index, object }
        it { is_expected.to allow_op_on_object :read_env, object }
      end

      context 'full access' do
        include_context 'admin setup'

        it { is_expected.to allow_op_on_object :read, object }
        it { is_expected.to allow_op_on_object :read_for_update, object }
        it { is_expected.to allow_op_on_object :update, object }
        it { is_expected.to allow_op_on_object :index, object }
        it { is_expected.to allow_op_on_object :read_env, object }
      end
    end

    context 'for a logged in user (defensive)' do
      it { is_expected.not_to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.not_to allow_op_on_object :read_env, object }
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }

      it { is_expected.not_to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.not_to allow_op_on_object :read_env, object }
    end

    context 'organization manager (defensive)' do
      before { org.add_manager(user) }

      it { is_expected.to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.to allow_op_on_object :index, object }
      it { is_expected.not_to allow_op_on_object :read_env, object }
    end

    context 'organization billing manager (defensive)' do
      before { org.add_billing_manager(user) }

      it { is_expected.not_to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.not_to allow_op_on_object :read_env, object }
    end

    context 'organization auditor (defensive)' do
      before { org.add_auditor(user) }

      it { is_expected.not_to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.not_to allow_op_on_object :read_env, object }
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }

      it { is_expected.not_to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.not_to allow_op_on_object :read_env, object }
    end

    context 'space auditor' do
      before do
        org.add_user(user)
        space.add_auditor(user)
      end

      it { is_expected.to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.to allow_op_on_object :index, object }
      it { is_expected.not_to allow_op_on_object :read_env, object }
    end

    context 'space manager (defensive)' do
      before do
        org.add_user(user)
        space.add_manager(user)
      end

      it { is_expected.to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.to allow_op_on_object :index, object }
      it { is_expected.not_to allow_op_on_object :read_env, object }
    end

    context 'space developer' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end

      it { is_expected.to allow_op_on_object :read, object }
      it { is_expected.to allow_op_on_object :read_env, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }

      context 'when the organization is suspended' do
        before { allow(object.space.organization).to receive(:suspended?).and_return(true) }

        it { is_expected.to allow_op_on_object :read, object }
        it { is_expected.not_to allow_op_on_object :read_for_update, object }
        it { is_expected.not_to allow_op_on_object :update, object }
        it { is_expected.to allow_op_on_object :index, object }
      end
    end

    context "space developer in service instance's space (but no read access to app's space)" do
      before do
        service_instance.space.organization.add_user(user)
        service_instance.space.add_developer(user)
      end

      it { is_expected.not_to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.not_to allow_op_on_object :read_env, object }
    end

    context 'any user using client without cloud_controller.write' do
      let(:scopes) { ['cloud_controller.read'] }

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        space.add_manager(user)
        space.add_developer(user)
        space.add_auditor(user)
      end

      it { is_expected.to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.to allow_op_on_object :index, object }
    end

    context 'any user using client without cloud_controller.read' do
      let(:scopes) { [] }

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        space.add_manager(user)
        space.add_developer(user)
        space.add_auditor(user)
      end

      it { is_expected.not_to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.not_to allow_op_on_object :read_env, object }
    end
  end
end
