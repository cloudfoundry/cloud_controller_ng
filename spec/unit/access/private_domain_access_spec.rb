require "spec_helper"

module VCAP::CloudController
  describe PrivateDomainAccess, type: :access do
    subject(:access) { PrivateDomainAccess.new(Security::AccessContext.new) }
    let(:token) {{ 'scope' => ['cloud_controller.read', 'cloud_controller.write'] }}

    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:object) { VCAP::CloudController::PrivateDomain.make owning_organization: org }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'admin' do
      include_context :admin_setup

      before { FeatureFlag.make(name: "private_domain_creation", enabled: false) }

      it_behaves_like :full_access

      context 'changing organization' do
        it 'succeeds even if not an org manager in the new org' do
          object.owning_organization = Organization.make
          object.owning_organization.add_user(user)
          expect(subject.update?(object)).to be_truthy
        end
      end
    end

    context "organization manager" do
      before { org.add_manager(user) }
      it_behaves_like :full_access

      context "when the organization is suspended" do
        before { allow(object).to receive(:in_suspended_org?).and_return(true) }
        it_behaves_like :read_only
      end

      context 'changing organization' do
        it 'succeeds if an org manager in the new org' do
          object.owning_organization = Organization.make
          object.owning_organization.add_manager(user)
          expect(subject.update?(object)).to be_truthy
        end

        it 'fails if not an org manager in the new org' do
          object.owning_organization = Organization.make
          object.owning_organization.add_user(user)
          expect(subject.update?(object)).to be_falsey
        end
      end

      context 'when private_domain_creation FeatureFlag is disabled' do
        it 'cannot create a private domain' do
          FeatureFlag.make(name: "private_domain_creation", enabled: false, error_message: nil)
          expect{subject.create?(object)}.to raise_error(VCAP::Errors::ApiError, /private_domain_creation/)
        end
      end
    end

    context "organization auditor (defensive)" do
      before { org.add_auditor(user) }
      it_behaves_like :read_only
    end

    context "organization billing manager (defensive)" do
      before { org.add_billing_manager(user) }
      it_behaves_like :no_access
    end

    context "organization user (defensive)" do
      before { org.add_user(user) }
      it_behaves_like :no_access
    end

    context "user in a different organization (defensive)" do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_user(user)
      end

      it_behaves_like :no_access
    end

    context "manager in a different organization (defensive)" do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_manager(user)
      end

      it_behaves_like :no_access
    end

    context "a user that isnt logged in (defensive)" do
      let(:user) { nil }
      it_behaves_like :no_access
    end

    context 'any user using client without cloud_controller.write' do
      let(:token) {{'scope' => ['cloud_controller.read']}}

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
      end

      it_behaves_like :read_only
    end

    context 'any user using client without cloud_controller.read' do
      let(:token) {{'scope' => []}}

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
