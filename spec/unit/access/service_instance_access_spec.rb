require 'spec_helper'

module VCAP::CloudController
  describe ServiceInstanceAccess, type: :access do
    subject(:access) { ServiceInstanceAccess.new(Security::AccessContext.new) }
    let(:token) {{ 'scope' => ['cloud_controller.read', 'cloud_controller.write'] }}
    let(:user) { VCAP::CloudController::User.make }

    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(:organization => org) }
    let(:service) { VCAP::CloudController::Service.make }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(:service => service) }
    let(:object) { VCAP::CloudController::ManagedServiceInstance.make(:service_plan => service_plan, :space => space) }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'admin' do
      include_context :admin_setup
      it_behaves_like :full_access

      context 'managed service instance' do
        it 'does not delegate to the ManagedServiceInstanceAccess' do
          expect_any_instance_of(ManagedServiceInstanceAccess).not_to receive(:allowed?).with(object)
          subject.create?(object)
          subject.read_for_update?(object)
          subject.update?(object)
        end
      end

      context 'user provided service instance' do
        let(:object) {VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }

        it 'does not delegate to the UserProvidedServiceInstanceAccess' do
          expect_any_instance_of(UserProvidedServiceInstanceAccess).not_to receive(:allowed?).with(object)
          subject.create?(object)
          subject.read_for_update?(object)
          subject.update?(object)
        end
      end
    end

    context 'space developer' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end
      it_behaves_like :full_access

      context 'when the organization is suspended' do
        before { allow(object).to receive(:in_suspended_org?).and_return(true) }
        it_behaves_like :read_only
      end

      it 'allows the user to read the permissions of the service instance' do
        expect(subject).to allow_op_on_object(:read_permissions, object)
      end
    end

    context 'space auditor' do
      before do
        org.add_user(user)
        space.add_auditor(user)
      end

      it_behaves_like :read_only

      it 'allows the user to read the permissions of the service instance' do
        expect(subject).to allow_op_on_object(:read_permissions, object)
      end
    end

    context 'organization manager (defensive)' do
      before { org.add_manager(user) }
      it_behaves_like :no_access

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, object)
      end
    end

    context 'organization billing manager (defensive)' do
      before { org.add_billing_manager(user) }
      it_behaves_like :no_access

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, object)
      end
    end

    context 'organization auditor (defensive)' do
      before { org.add_auditor(user) }
      it_behaves_like :no_access

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, object)
      end
    end

    context 'space manager (defensive)' do
      before do
        org.add_user(user)
        space.add_manager(user)
      end

      it_behaves_like :no_access
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }
      it_behaves_like :no_access

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, object)
      end
    end

    context 'user in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_user(user)
      end

      it_behaves_like :no_access

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, object)
      end
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
      let(:token) {{ 'scope' => [] }}

      it_behaves_like :no_access

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, object)
      end
    end

    describe 'a user with full org and space permissions using a client with limited scope' do
      let(:token) {{'scope' => scope}}

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        space.add_manager(user)
        space.add_developer(user)
        space.add_auditor(user)
      end

      context 'with only cloud_controller.read scope' do
        let(:scope) { ['cloud_controller.read'] }
        it_behaves_like :read_only
        it { is_expected.to allow_op_on_object(:read_permissions, object) }
      end

      context 'with only cloud_controller_service_permissions.read scope' do
        let(:scope) { ['cloud_controller_service_permissions.read'] }

        it 'allows the user to read the permissions of the service instance' do
          expect(subject).to allow_op_on_object(:read_permissions, object)
        end

        # All other actions are disallowed
        it_behaves_like :no_access
      end

      context 'with no cloud_controller scopes' do
        let(:scope) { [] }

        it_behaves_like :no_access
        it { is_expected.not_to allow_op_on_object(:read_permissions, object) }
      end
    end

    describe "#allowed?" do
      context 'managed service instance' do
        it 'delegates to the ManagedServiceInstanceAccess' do
          expect_any_instance_of(ManagedServiceInstanceAccess).to receive(:allowed?).with(object)
          subject.allowed?(object)
        end
      end

      context 'user provided service instance' do
        let(:object) {VCAP::CloudController::UserProvidedServiceInstance.make(:space => space) }

        it 'delegates to the UserProvidedServiceInstanceAccess' do
          expect_any_instance_of(UserProvidedServiceInstanceAccess).to receive(:allowed?).with(object)
          subject.allowed?(object)
        end
      end
    end
  end
end
