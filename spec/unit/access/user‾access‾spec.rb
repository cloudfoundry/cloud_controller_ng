require 'spec_helper'

module VCAP::CloudController
  RSpec.describe UserAccess, type: :access do
    subject(:access) { UserAccess.new(Security::AccessContext.new) }
    let(:object) { VCAP::CloudController::User.make }
    let(:user) { VCAP::CloudController::User.make }

    before { set_current_user(user) }

    it_behaves_like :admin_full_access
    it_behaves_like :admin_read_only_access

    context 'a user' do
      context 'has no_access to other users' do
        it_behaves_like :no_access
      end

      context 'has read access' do
        let(:user) { object }
        it { is_expected.not_to allow_op_on_object :create, object }
        it { is_expected.to allow_op_on_object :read, object }
        it { is_expected.not_to allow_op_on_object :read_for_update, object }
        # update only runs if read_for_update succeeds
        it { is_expected.not_to allow_op_on_object :update, object }
        it { is_expected.not_to allow_op_on_object :delete, object }
        it { is_expected.not_to allow_op_on_object :index, object.class }
      end
    end

    context 'for a non-logged in user' do
      let(:user) { nil }

      it_behaves_like :no_access
      it { should_not allow_op_on_object :index, object.class }
    end

    context 'any user using client without cloud_controller.read' do
      before { set_current_user(user, scopes: []) }

      it_behaves_like :no_access
      it { should_not allow_op_on_object :index, object.class }
    end
  end
end
