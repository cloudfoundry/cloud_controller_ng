require 'spec_helper'
require 'allowy/rspec'

module VCAP::CloudController::Models
  describe OrganizationAccess do
    subject(:access) { OrganizationAccess.new(double(:context, user: user, roles: roles)) }
    let(:org) { VCAP::CloudController::Models::Organization.make }
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
  end
end