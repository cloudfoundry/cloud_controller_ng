require 'spec_helper'

module VCAP::CloudController
  describe RouteAccess, type: :access do
    subject(:access) { RouteAccess.new(Security::AccessContext.new) }
    let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }

    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }
    let(:app) { VCAP::CloudController::AppFactory.make(space: space) }
    let(:object) { VCAP::CloudController::Route.make(domain: domain, space: space) }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'admin' do
      include_context :admin_setup

      before { FeatureFlag.make(name: 'route_creation', enabled: false) }

      it_behaves_like :full_access
      it { is_expected.to allow_op_on_object :reserved, nil }

      it 'can create wildcard routes' do
        object.host = '*'
        expect(subject.create?(object)).to be_truthy
      end

      it 'can update wildcard routes' do
        object.host = '*'
        expect(subject.update?(object)).to be_truthy
      end

      context 'changing the space' do
        it 'succeeds even if not a space developer in the new space' do
          new_space = Space.make(organization: object.space.organization)

          object.space = new_space
          expect(subject.update?(object)).to be_truthy
        end
      end
    end

    context 'organization manager' do
      before { org.add_manager(user) }
      it_behaves_like :read_only

      context 'when the organization is suspended' do
        before { allow(object).to receive(:in_suspended_org?).and_return(true) }
        it_behaves_like :read_only
      end
    end

    context 'organization auditor' do
      before { org.add_auditor(user) }
      it_behaves_like :read_only
    end

    context 'organization billing manager' do
      before { org.add_billing_manager(user) }
      it_behaves_like :no_access
    end

    context 'space manager' do
      before do
        org.add_user(user)
        space.add_manager(user)
      end

      it_behaves_like :read_only

      it 'cant create wildcard routes' do
        object.host = '*'
        expect(subject.create?(object)).to be_falsey
      end

      it 'cant update wildcard routes' do
        object.host = '*'
        expect(subject.update?(object)).to be_falsey
      end
    end

    context 'space developer' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end

      it_behaves_like :full_access

      it 'can create wildcard routes' do
        object.host = '*'
        expect(subject.create?(object)).to be_truthy
      end

      it 'can update wildcard routes' do
        object.host = '*'
        expect(subject.update?(object)).to be_truthy
      end

      context 'in a shared domain' do
        before do
          object.domain = SharedDomain.make
        end

        it 'cant create wildcard routes for shared domain' do
          object.host = '*'
          expect(subject.create?(object)).to be_falsey
        end

        it 'cant update wildcard routes for shared domain' do
          object.host = '*'
          expect(subject.update?(object)).to be_falsey
        end
      end

      context 'changing the space' do
        it 'succeeds if a space developer in the new space' do
          new_space = Space.make(organization: object.space.organization)
          new_space.add_developer(user)

          object.space = new_space
          expect(subject.update?(object)).to be_truthy
        end

        it 'fails if not a space developer in the new space' do
          new_space = Space.make(organization: object.space.organization)

          object.space = new_space
          expect(subject.update?(object)).to be_falsey
        end
      end

      context 'when the route_creation feature flag is disabled' do
        before { FeatureFlag.make(name: 'route_creation', enabled: false, error_message: nil) }

        it 'raises when attempting to create a route' do
          expect { subject.create?(object) }.to raise_error(VCAP::Errors::ApiError, /route_creation/)
        end

        it 'allows all other actions' do
          expect(subject.read_for_update?(object)).to be_truthy
          expect(subject.update?(object)).to be_truthy
          expect(subject.delete?(object)).to be_truthy
        end
      end
    end

    context 'space auditor' do
      before do
        org.add_user(user)
        space.add_auditor(user)
      end

      it_behaves_like :read_only
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
      let(:token) { nil }
      it_behaves_like :no_access
      it { is_expected.not_to allow_op_on_object :reserved, nil }
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
      it { is_expected.to allow_op_on_object :reserved, nil }
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
      it { is_expected.not_to allow_op_on_object :reserved, nil }
    end
  end
end
