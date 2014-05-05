require 'spec_helper'

module VCAP::CloudController
  describe BuildpackAccess, type: :access do
    before do
      token = {'scope' => 'cloud_controller.read cloud_controller.write'}
      VCAP::CloudController::SecurityContext.stub(:token).and_return(token)
    end

    subject(:access) { BuildpackAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:object) { VCAP::CloudController::Buildpack.make }

    context 'for an admin' do
      include_context :admin_setup
      it_behaves_like :full_access
      it { should allow_op_on_object :upload, object }
    end

    context 'for a logged in user' do
      it_behaves_like :read_only
      it { should_not allow_op_on_object :upload, object }

      context 'using a client without cloud_controller.read' do
        before do
          token = { 'scope' => ''}
          VCAP::CloudController::SecurityContext.stub(:token).and_return(token)
        end

        it_behaves_like :no_access
      end
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:roles) { double(:roles, :admin? => false, :none? => true, :present? => false) }
      it_behaves_like :no_access
      it { should_not allow_op_on_object :upload, object }
    end
  end
end
