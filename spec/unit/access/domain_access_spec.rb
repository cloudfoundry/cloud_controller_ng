require 'spec_helper'

module VCAP::CloudController
  describe DomainAccess, type: :access do
    subject(:access) { DomainAccess.new(Security::AccessContext.new) }
    let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }

    let(:user) { User.make }
    let(:org) { Organization.make }
    let(:space) { Space.make(organization: org) }

    let(:object) { Domain.make }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'when the domain is a private domain' do
      let(:object) { PrivateDomain.make(owning_organization: org) }

      context 'admin' do
        include_context :admin_setup

        before { FeatureFlag.make(name: 'private_domain_creation', enabled: false) }

        it_behaves_like :full_access
      end

      context 'organization manager' do
        before { org.add_manager(user) }
        it_behaves_like :full_access

        context 'when private_domain_creation FeatureFlag is disabled' do
          it 'cannot create a private domain' do
            FeatureFlag.make(name: 'private_domain_creation', enabled: false, error_message: nil)
            expect { subject.create?(object) }.to raise_error(VCAP::Errors::ApiError, /private_domain_creation/)
          end
        end
      end

      context 'organization auditor' do
        before { org.add_auditor(user) }
        it_behaves_like :read_only
      end

      context 'organization user (defensive)' do
        before { org.add_user(user) }
        it_behaves_like :no_access
      end

      context 'organization billing manager (defensive)' do
        before { org.add_billing_manager(user) }
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
        let(:token) { { 'scope' => ['cloud_controller.read'] } }

        before do
          org.add_user(user)
          org.add_manager(user)
          org.add_billing_manager(user)
          org.add_auditor(user)
          space.add_manager(user)
          space.add_developer(user)
          space.add_auditor(user)
        end

        it_behaves_like :read_only
      end

      context 'any user using client without cloud_controller.read' do
        let(:token) { { 'scope' => [] } }

        before do
          org.add_user(user)
          org.add_manager(user)
          org.add_billing_manager(user)
          org.add_auditor(user)
          space.add_manager(user)
          space.add_developer(user)
          space.add_auditor(user)
        end

        it_behaves_like :no_access
      end
    end

    context 'when the domain is a shared domain' do
      let(:object) { SharedDomain.make }

      it_behaves_like :admin_full_access
      it_behaves_like :read_only

      context 'a user that isnt logged in (defensive)' do
        let(:user) { nil }
        let(:token) { { 'scope' => [] } }

        it_behaves_like :no_access
      end

      context 'any user using client without cloud_controller.read' do
        let(:token) { { 'scope' => [] } }

        before do
          org.add_user(user)
          org.add_manager(user)
          org.add_billing_manager(user)
          org.add_auditor(user)
          space.add_manager(user)
          space.add_developer(user)
          space.add_auditor(user)
        end

        it_behaves_like :no_access
      end
    end
  end
end
