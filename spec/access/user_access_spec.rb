require 'spec_helper'

module VCAP::CloudController::Models
  describe UserAccess, type: :access do
    subject(:access) { UserAccess.new(double(:context, user: current_user, roles: roles)) }
    let(:object) { VCAP::CloudController::Models::User.make }
    let(:current_user) { VCAP::CloudController::Models::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }

    it_should_behave_like :admin_full_access

    context 'for a non-admin' do
      it_behaves_like :no_access
    end
  end
end