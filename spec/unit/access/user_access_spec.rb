require 'spec_helper'

module VCAP::CloudController
  describe UserAccess, type: :access do
    subject(:access) { UserAccess.new(Security::AccessContext.new) }
    let(:token) {{ 'scope' => ['cloud_controller.read', 'cloud_controller.write'] }}
    let(:object) { VCAP::CloudController::User.make }
    let(:user) { VCAP::CloudController::User.make }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    it_should_behave_like :admin_full_access

    context 'for a logged in user' do
      it_behaves_like :no_access
      it { should_not allow_op_on_object :index, object.class }
    end

    context 'for a non-logged in user' do
      let(:user) {nil}
      it_behaves_like :no_access
      it { should_not allow_op_on_object :index, object.class }
    end

    context 'any user using client without cloud_controller.read' do
      let(:token) { {'scope' => []}}

      it_behaves_like :no_access
      it { should_not allow_op_on_object :index, object.class }
    end
  end
end
