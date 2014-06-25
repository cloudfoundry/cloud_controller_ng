require 'spec_helper'

module VCAP::CloudController
  describe SecurityGroupAccess, type: :access do
    before do
      token = {'scope' => 'cloud_controller.read cloud_controller.write'}
      SecurityContext.stub(:token).and_return(token)
    end

    subject(:access) { SecurityGroupAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:object) { SecurityGroup.make }

    context 'admin' do
      it_should_behave_like :admin_full_access
    end

    context 'non admin' do
      it_should_behave_like :no_access
    end
  end
end
