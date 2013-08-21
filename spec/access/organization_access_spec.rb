require 'spec_helper'

module VCAP::CloudController::Models
  describe OrganizationAccess do
    subject(:access) { OrganizationAccess.new(double(:context, user: user, roles: roles)) }
    let(:org) { VCAP::CloudController::Models::Organization.make }
    let(:other_org) { VCAP::CloudController::Models::Organization.make }
    let(:user) { VCAP::CloudController::Models::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }

    describe 'update?' do
      context 'for an organization manager' do
        before { org.add_manager(user) }

        context 'with an active organization' do
          it { should be_able_to :update, org }
        end

        context 'with a suspended organization' do
          before { org.set(status: 'suspended') }

          it { should_not be_able_to :update, org }
        end
      end

      context 'for an org user' do
        before { org.add_user(user) }

        it { should_not be_able_to :update, org }
      end

      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }

        context 'with a suspended organization' do
          before { org.set(status: 'suspended') }

          it { should be_able_to :update, org }
        end
      end
    end

    describe 'read?' do
      context 'for a user not in the org' do
        before { other_org.add_user(user) }
        it { should_not be_able_to :read, org }
      end

      context 'for a user in the org' do
        before { org.add_user(user) }
        it { should be_able_to :read, org }
      end

      context 'for a billing manager in the org' do
        before { org.add_billing_manager(user) }
        it { should be_able_to :read, org }
      end

      context 'for a manager in the org' do
        before { org.add_manager(user) }
        it { should be_able_to :read, org }
      end

      context 'for an auditor in the org' do
        before { org.add_auditor(user) }
        it { should be_able_to :read, org }
      end

      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }
        it { should be_able_to :read, org }
      end
    end

    describe 'create?' do
      context 'for a user not in the org' do
        before { other_org.add_user(user) }
        it { should_not be_able_to :create }
      end

      context 'for a user in the org' do
        before { org.add_user(user) }
        it { should_not be_able_to :create, org }
      end

      context 'for a billing manager in the org' do
        before { org.add_billing_manager(user) }
        it { should_not be_able_to :create, org }
      end

      context 'for a manager in the org' do
        before { org.add_manager(user) }
        it { should_not be_able_to :create, org }
      end

      context 'for an auditor in the org' do
        before { org.add_auditor(user) }
        it { should_not be_able_to :create, org }
      end

      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }
        it { should be_able_to :create }
      end
    end

    describe 'delete?' do
      context 'for a user not in the org' do
        before { other_org.add_user(user) }
        it { should_not be_able_to :delete, org }
      end

      context 'for a user in the org' do
        before { org.add_user(user) }
        it { should_not be_able_to :delete, org }
      end

      context 'for a billing manager in the org' do
        before { org.add_billing_manager(user) }
        it { should_not be_able_to :delete, org }
      end

      context 'for a manager in the org' do
        before { org.add_manager(user) }
        it { should_not be_able_to :delete, org }
      end

      context 'for an auditor in the org' do
        before { org.add_auditor(user) }
        it { should_not be_able_to :delete, org }
      end

      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }
        it { should be_able_to :delete, org }
      end
    end
  end
end