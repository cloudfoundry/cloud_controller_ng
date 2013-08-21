require 'spec_helper'

module VCAP::CloudController::Models
  describe UserAccess do
    subject(:access) { UserAccess.new(double(:context, user: current_user, roles: roles)) }
    let(:user) { VCAP::CloudController::Models::User.make }
    let(:current_user) { VCAP::CloudController::Models::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }

    describe 'create?' do
      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }
        it { should be_able_to :create, user }
      end

      context 'for a non-admin' do
        it { should_not be_able_to :create, user }
      end
    end

    describe 'read?' do
      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }
        it { should be_able_to :read, user }
      end

      context 'for a non-admin' do
        it { should_not be_able_to :read, user }
      end
    end

    describe 'update?' do
      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }
        it { should be_able_to :update, user }
      end

      context 'for a non-admin' do
        it { should_not be_able_to :update, user }
      end
    end

    describe 'delete?' do
      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }
        it { should be_able_to :delete, user }
      end

      context 'for a non-admin' do
        it { should_not be_able_to :delete, user }
      end
    end
  end
end