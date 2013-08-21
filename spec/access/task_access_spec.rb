require 'spec_helper'

module VCAP::CloudController::Models
  describe TaskAccess do
    subject(:access) { TaskAccess.new(double(:context, user: user, roles: roles)) }
    let(:user) { VCAP::CloudController::Models::User.make }
    let(:roles) { double(:roles, :admin? => false, :none? => false, :present? => true) }
    let(:org) { VCAP::CloudController::Models::Organization.make }
    let(:space) { VCAP::CloudController::Models::Space.make(:organization => org) }
    let(:app) { VCAP::CloudController::Models::App.make(:space => space) }
    let(:task) { VCAP::CloudController::Models::Task.make(:app => app) }

    describe 'create?' do
      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }
        it { should be_able_to :create, task }
      end

      context 'for an org user' do
        before { org.add_user(user) }
        it { should_not be_able_to :create, task }
      end

      context 'for an organization manager' do
        before { org.add_manager(user) }
        it { should_not be_able_to :create, task }
      end

      context 'for a space manager' do
        before do
          org.add_user(user)
          space.add_manager(user)
        end
        it { should_not be_able_to :create, task }
      end

      context 'for a space developer' do
        before do
          org.add_user(user)
          space.add_developer(user)
        end
        it { should be_able_to :create, task }
      end

      context 'for a space auditor' do
        before do
          org.add_user(user)
          space.add_auditor(user)
        end
        it { should_not be_able_to :create, task }
      end
    end

    describe 'read?' do
      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }
        it { should be_able_to :read, task }
      end

      context 'for an org user' do
        before { org.add_user(user) }
        it { should_not be_able_to :read, task }
      end

      context 'for an organization manager' do
        before { org.add_manager(user) }
        it { should be_able_to :read, task }
      end

      context 'for a space manager' do
        before do
          org.add_user(user)
          space.add_manager(user)
        end
        it { should be_able_to :read, task }
      end

      context 'for a space developer' do
        before do
          org.add_user(user)
          space.add_developer(user)
        end
        it { should be_able_to :read, task }
      end

      context 'for a space auditor' do
        before do
          org.add_user(user)
          space.add_auditor(user)
        end
        it { should be_able_to :read, task }
      end
    end

    describe 'update?' do
      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }
        it { should be_able_to :update, task }
      end

      context 'for an org user' do
        before { org.add_user(user) }
        it { should_not be_able_to :update, task }
      end

      context 'for an organization manager' do
        before { org.add_manager(user) }
        it { should_not be_able_to :update, task }
      end

      context 'for a space manager' do
        before do
          org.add_user(user)
          space.add_manager(user)
        end
        it { should_not be_able_to :update, task }
      end

      context 'for a space developer' do
        before do
          org.add_user(user)
          space.add_developer(user)
        end
        it { should be_able_to :update, task }
      end

      context 'for a space auditor' do
        before do
          org.add_user(user)
          space.add_auditor(user)
        end
        it { should_not be_able_to :update, task }
      end
    end

    describe 'delete?' do
      context 'for a cloud foundry admin' do
        before { roles.stub(:admin?).and_return(true) }
        it { should be_able_to :delete, task }
      end

      context 'for an org user' do
        before { org.add_user(user) }
        it { should_not be_able_to :delete, task }
      end

      context 'for an organization manager' do
        before { org.add_manager(user) }
        it { should_not be_able_to :delete, task }
      end

      context 'for a space manager' do
        before do
          org.add_user(user)
          space.add_manager(user)
        end
        it { should_not be_able_to :delete, task }
      end

      context 'for a space developer' do
        before do
          org.add_user(user)
          space.add_developer(user)
        end
        it { should be_able_to :delete, task }
      end

      context 'for a space auditor' do
        before do
          org.add_user(user)
          space.add_auditor(user)
        end
        it { should_not be_able_to :delete, task }
      end
    end
  end
end