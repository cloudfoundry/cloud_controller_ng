require 'spec_helper'

module VCAP::CloudController
  describe SecurityGroupAccess, type: :access do
    subject(:access) { SecurityGroupAccess.new(Security::AccessContext.new) }
    let(:token) {{ 'scope' => ['cloud_controller.read', 'cloud_controller.write'] }}
    let(:user) { User.make }
    let(:object) { SecurityGroup.make }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'admin' do
      it_should_behave_like :admin_full_access
    end

    context 'non admin' do
      it_should_behave_like :no_access
      it { is_expected.not_to allow_op_on_object :index, object }
    end
  end
end
