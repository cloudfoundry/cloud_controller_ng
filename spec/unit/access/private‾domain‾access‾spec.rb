require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PrivateDomainAccess, type: :access do
    subject(:access) { PrivateDomainAccess.new(Security::AccessContext.new) }
    let(:scopes) { ['cloud_controller.read', 'cloud_controller.write'] }

    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:object) { VCAP::CloudController::PrivateDomain.make owning_organization: org }

    before { set_current_user(user, scopes: scopes) }

    it_behaves_like :admin_read_only_access

    context 'admin' do
      include_context :admin_setup

      before { FeatureFlag.make(name: 'private_domain_creation', enabled: false) }

      it_behaves_like :full_access
    end

    context 'organization manager' do
      before { org.add_manager(user) }
      it_behaves_like :full_access

      context 'when the organization is suspended' do
        before { allow(object).to receive(:in_suspended_org?).and_return(true) }
        it_behaves_like :read_only_access
      end

      context 'when private_domain_creation FeatureFlag is disabled' do
        it 'cannot create a private domain' do
          FeatureFlag.make(name: 'private_domain_creation', enabled: false, error_message: nil)
          expect { subject.create?(object) }.to raise_error(CloudController::Errors::ApiError, /private_domain_creation/)
        end
      end
    end

    context 'organization auditor (defensive)' do
      before { org.add_auditor(user) }
      it_behaves_like :read_only_access
    end

    context 'organization billing manager (defensive)' do
      before { org.add_billing_manager(user) }
      it_behaves_like :no_access
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }
      it_behaves_like :no_access
    end

    context 'user in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_user(user)
      end

      it_behaves_like :no_access
    end

    context 'manager in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_manager(user)
      end

      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      it_behaves_like :no_access
    end

    context 'any user using client without cloud_controller.write' do
      let(:scopes) { ['cloud_controller.read'] }

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
      end

      it_behaves_like :read_only_access
    end

    context 'any user using client without cloud_controller.read' do
      let(:scopes) { [] }

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
      end

      it_behaves_like :no_access
    end
  end
end
