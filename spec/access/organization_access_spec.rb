require 'spec_helper'

module VCAP::CloudController
  describe OrganizationAccess, type: :access do
    subject(:access) { OrganizationAccess.new(double(:context, user: user, roles: roles)) }
    let(:object) { VCAP::CloudController::Organization.make }
    let(:user) { VCAP::CloudController::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }

    it_should_behave_like :admin_full_access

    context 'an admin of the organization' do
      include_context :admin_setup

      context 'changing the name' do
        before { object.name = 'my new name' }
        it { should be_able_to :update, object }
      end

      context 'with a suspended organization' do
        before { object.set(status: 'suspended') }
        it_behaves_like :full_access
      end
    end

    context 'a user in the organization' do
      before { object.add_user(user) }
      it_behaves_like :read_only
    end

    context 'a user not in the organization' do
      it_behaves_like :no_access
    end

    context 'a billing manager for the organization' do
      before { object.add_billing_manager(user) }
      it_behaves_like :read_only
    end

    context 'a manager for the organization' do
      before { object.add_manager(user) }

      context 'with an active organization' do
        it { should_not be_able_to :create, object }
        it { should be_able_to :read, object }
        it { should be_able_to :update, object }
        it { should_not be_able_to :delete, object }
      end

      context 'changing the name' do
        before { object.name = 'my new name' }
        it { should be_able_to :update, object }
      end

      context 'with a suspended organization' do
        before { object.set(status: 'suspended') }
        it_behaves_like :read_only
      end
    end

    context 'an auditor for the organization' do
      before { object.add_auditor(user) }
      it_behaves_like :read_only
    end
  end
end
