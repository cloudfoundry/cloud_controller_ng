require 'spec_helper'

module VCAP::CloudController::Models
  describe SpaceAccess, type: :access do
    subject(:access) { SpaceAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::Models::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:org) { VCAP::CloudController::Models::Organization.make }
    let(:object) { VCAP::CloudController::Models::Space.make(:organization => org) }

    it_should_behave_like :admin_full_access

    context 'organization manager' do
      before { org.add_manager(user) }
      it_behaves_like :full_access
    end

    context 'space manager' do
      before do
        org.add_user(user)
        object.add_manager(user)
      end

      it { should_not be_able_to :create, object }
      it { should be_able_to :read, object }
      it { should be_able_to :update, object }
      it { should_not be_able_to :delete, object }
    end

    context 'space developer' do
      before do
        org.add_user(user)
        object.add_developer(user)
      end

      it_behaves_like :read_only
    end

    context 'space auditor' do
      before do
        org.add_user(user)
        object.add_auditor(user)
      end

      it_behaves_like :read_only
    end

    context 'organization auditor (defensive)' do
      before { org.add_auditor(user) }
      it_behaves_like :no_access
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }
      it_behaves_like :no_access
    end

    context 'user in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Models::Organization.make
        different_organization.add_user(user)
      end

      it_behaves_like :no_access
    end

    context 'manager in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Models::Organization.make
        different_organization.add_manager(user)
      end

      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:roles) { double(:roles, :admin? => false, :none? => true, :present? => false) }
      it_behaves_like :no_access
    end
  end
end