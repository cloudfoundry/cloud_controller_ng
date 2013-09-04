require 'spec_helper'

module VCAP::CloudController
  describe JobAccess, type: :access do
    subject(:access) { JobAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:object) { VCAP::CloudController::Job.new }

    it_should_behave_like :admin_full_access

    context 'a logged in user' do
      it_behaves_like :read_only
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:roles) { double(:roles, :admin? => false, :none? => true, :present? => false) }
      it_behaves_like :no_access
    end
  end
end
