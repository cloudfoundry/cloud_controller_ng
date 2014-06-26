require 'spec_helper'

module VCAP::CloudController
  describe BuildpackAccess, type: :access do
    subject(:access) { BuildpackAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:object) { VCAP::CloudController::Buildpack.make }

    before do
      token = {'scope' => scope }
      allow(VCAP::CloudController::SecurityContext).to receive(:token).and_return(token)
    end

    context 'for an admin' do
      let(:scope) { 'cloud_controller.admin' }
      include_context :admin_setup
      it_behaves_like :full_access
      it { is_expected.to allow_op_on_object :upload, object }
    end

    context 'for a logged in user' do
      let(:scope) { 'cloud_controller.read cloud_controller.write' }
      it_behaves_like :read_only
      it { is_expected.not_to allow_op_on_object :upload, object }

      context 'using a client without cloud_controller.read' do
        let(:scope) { '' }

        it_behaves_like :no_access
        it { is_expected.not_to allow_op_on_object :upload, object }
      end
    end
  end
end
