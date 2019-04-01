require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildpackAccess, type: :access do
    subject(:access) { BuildpackAccess.new(Security::AccessContext.new) }
    let(:user) { VCAP::CloudController::User.make }
    let(:object) { VCAP::CloudController::Buildpack.make }

    it_should_behave_like :admin_read_only_access

    context 'for an admin' do
      before { set_current_user_as_admin }

      include_context :admin_setup
      it_behaves_like :full_access
      it { is_expected.to allow_op_on_object :upload, object }
    end

    context 'for a logged in user' do
      before { set_current_user(user) }

      it_behaves_like :read_only_access
      it { is_expected.not_to allow_op_on_object :upload, object }

      context 'using a client without cloud_controller.read' do
        before { set_current_user(user, scopes: ['cloud_controller.write']) }

        it_behaves_like :no_access
        it { is_expected.not_to allow_op_on_object :upload, object }
      end
    end
  end
end
