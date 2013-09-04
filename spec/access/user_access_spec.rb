require 'spec_helper'

module VCAP::CloudController
  describe UserAccess, type: :access do
    subject(:access) { UserAccess.new(double(:context, user: current_user, roles: roles)) }
    let(:object) { VCAP::CloudController::User.make }
    let(:current_user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }

    it_should_behave_like :admin_full_access

    context 'for a logged in user' do
      it_behaves_like :read_only
    end

    context 'for a non-logged in user' do
      include_context :logged_out_setup
      it_behaves_like :no_access
    end
  end
end
