require 'spec_helper'

module VCAP::CloudController
  describe ServiceInstanceAccess, type: :access do
    subject(:access) { ServiceInstanceAccess.new(Security::AccessContext.new) }
    let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }
    let(:user) { VCAP::CloudController::User.make }

    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:service) { VCAP::CloudController::Service.make }
    let(:service_plan_active) { true }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service, active: service_plan_active) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(service_plan: service_plan, space: space) }

    before do
      SecurityContext.set(user, token)
    end

    after do
      SecurityContext.clear
    end

    context 'admin' do
      include_context :admin_setup
      it_behaves_like :full_access do
        let(:object) { service_instance }
      end

      context 'managed service instance' do
        it 'does not delegate to the ManagedServiceInstanceAccess' do
          expect_any_instance_of(ManagedServiceInstanceAccess).not_to receive(:allowed?).with(service_instance)
          subject.create?(service_instance)
          subject.read_for_update?(service_instance)
          subject.update?(service_instance)
        end
      end

      context 'user provided service instance' do
        let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }

        it 'does not delegate to the UserProvidedServiceInstanceAccess' do
          expect_any_instance_of(UserProvidedServiceInstanceAccess).not_to receive(:allowed?).with(service_instance)
          subject.create?(service_instance)
          subject.read_for_update?(service_instance)
          subject.update?(service_instance)
        end
      end

      context 'when the service_instance_creation feature flag is not set' do
        before do
          FeatureFlag.make(name: 'service_instance_creation', enabled: false, error_message: nil)
        end

        it_behaves_like :full_access do
          let(:object) { service_instance }
        end
      end

      it 'returns true for purge' do
        expect(subject).to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'space developer' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end
      it_behaves_like :full_access do
        let(:object) { service_instance }
      end

      context 'when the organization is suspended' do
        before { allow(service_instance).to receive(:in_suspended_org?).and_return(true) }
        it_behaves_like :read_only_access do
          let(:object) { service_instance }
        end
      end

      it 'allows the user to read the permissions of the service instance' do
        expect(subject).to allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end

      context 'when the service_instance_creation feature flag is not set' do
        before do
          FeatureFlag.make(name: 'service_instance_creation', enabled: false, error_message: nil)
        end

        it 'allows all operations except create' do
          expect { subject.create?(service_instance) }.to raise_error(VCAP::Errors::ApiError, /service_instance_creation/)
        end
      end

      context 'updating a service instance that is currently part of an invisible plan' do
        let(:service_plan_active) { false }

        it 'is allowed' do
          expect(subject).to allow_op_on_object(:read_for_update, service_instance)
        end
      end

      context 'updating a service instance to become part of an invisible plan' do
        let(:service_plan_active) { false }

        it 'is not allowed' do
          expect(subject).to_not allow_op_on_object(:update, service_instance)
        end
      end

      context 'when the service broker is space-scoped' do
        before do
          broker = service.service_broker
          broker.space = space
          broker.save
        end

        it 'returns true for purge' do
          expect(subject).to allow_op_on_object(:purge, service_instance)
        end
      end
    end

    context 'space auditor' do
      before do
        org.add_user(user)
        space.add_auditor(user)
      end

      it_behaves_like :read_only_access do
        let(:object) { service_instance }
      end

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'organization manager (defensive)' do
      before { org.add_manager(user) }
      it_behaves_like :read_only_access do
        let(:object) { service_instance }
      end

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'organization billing manager (defensive)' do
      before { org.add_billing_manager(user) }
      it_behaves_like :no_access do
        let(:object) { service_instance }
      end

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'organization auditor (defensive)' do
      before { org.add_auditor(user) }
      it_behaves_like :no_access do
        let(:object) { service_instance }
      end

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'space manager (defensive)' do
      before do
        org.add_user(user)
        space.add_manager(user)
      end

      it_behaves_like :read_only_access do
        let(:object) { service_instance }
      end

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }
      it_behaves_like :no_access do
        let(:object) { service_instance }
      end

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'user in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_user(user)
      end

      it_behaves_like :no_access do
        let(:object) { service_instance }
      end

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'manager in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_manager(user)
      end

      it_behaves_like :no_access do
        let(:object) { service_instance }
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:token) { { 'scope' => [] } }

      it_behaves_like :no_access do
        let(:object) { service_instance }
      end

      it 'does not allow the user to read the permissions of the service instance' do
        expect(subject).to_not allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    describe 'a user with full org and space permissions using a client with limited scope' do
      let(:token) { { 'scope' => scope } }

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
        it_behaves_like :read_only_access do
          let(:object) { service_instance }
        end
        it { is_expected.to allow_op_on_object(:read_permissions, service_instance) }
      end

      context 'with only cloud_controller_service_permissions.read scope' do
        let(:scope) { ['cloud_controller_service_permissions.read'] }

        it 'allows the user to read the permissions of the service instance' do
          expect(subject).to allow_op_on_object(:read_permissions, service_instance)
        end

        # All other actions are disallowed
        it_behaves_like :no_access do
          let(:object) { service_instance }
        end
      end

      context 'with no cloud_controller scopes' do
        let(:scope) { [] }

        it_behaves_like :no_access do
          let(:object) { service_instance }
        end
        it { is_expected.not_to allow_op_on_object(:read_permissions, service_instance) }
      end
    end

    describe '#allowed?' do
      context 'managed service instance' do
        it 'delegates to the ManagedServiceInstanceAccess' do
          expect_any_instance_of(ManagedServiceInstanceAccess).to receive(:allowed?).with(service_instance)
          subject.allowed?(service_instance)
        end
      end

      context 'user provided service instance' do
        let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }

        it 'delegates to the UserProvidedServiceInstanceAccess' do
          expect_any_instance_of(UserProvidedServiceInstanceAccess).to receive(:allowed?).with(service_instance)
          subject.allowed?(service_instance)
        end
      end
    end
  end
end
