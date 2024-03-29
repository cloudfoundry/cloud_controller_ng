require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceInstanceAccess, type: :access do
    subject(:access) { ServiceInstanceAccess.new(Security::AccessContext.new) }
    let(:scopes) { ['cloud_controller.read', 'cloud_controller.write'] }
    let(:user) { VCAP::CloudController::User.make }

    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:service) { VCAP::CloudController::Service.make }
    let(:service_plan_active) { true }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service, active: service_plan_active) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(service_plan:, space:) }

    before { set_current_user(user, scopes:) }

    it_behaves_like 'admin read only access' do
      let(:object) { service_instance }
    end

    context 'admin' do
      include_context 'admin setup'

      it_behaves_like 'full access' do
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
        let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space:) }

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

        it_behaves_like 'full access' do
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

      it_behaves_like 'full access' do
        let(:object) { service_instance }
      end

      context 'when the organization is suspended' do
        before { allow(service_instance).to receive(:in_suspended_org?).and_return(true) }

        it_behaves_like 'read only access' do
          let(:object) { service_instance }
        end
      end

      it 'allows the user to have BOTH manage and read permissions of the service instance' do
        expect(subject).to allow_op_on_object(:manage_permissions, service_instance)
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
          expect { subject.create?(service_instance) }.to raise_error(CloudController::Errors::ApiError, /service_instance_creation/)
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

      it_behaves_like 'read only access' do
        let(:object) { service_instance }
      end

      it 'does NOT allow the user to have manage permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:manage_permissions, service_instance)
      end

      it 'allows the user to have read permissions of the service instance' do
        expect(subject).to allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'space developer in a space that the service instance has been shared into' do
      before do
        org.add_user(user)
        target_space = VCAP::CloudController::Space.make(organization: org)
        target_space.add_developer(user)
        service_instance.add_shared_space(target_space)
      end

      context 'when the space of the service instance is visible' do
        it_behaves_like 'read only access' do
          let(:object) { service_instance }
        end

        it 'does NOT allow the user to have manage permissions of the service instance' do
          expect(subject).not_to allow_op_on_object(:manage_permissions, service_instance)
        end

        it 'allows the user to have read permissions of the service instance' do
          expect(subject).to allow_op_on_object(:read_permissions, service_instance)
        end

        it 'does NOT allow the user to read default credentials of the service instance' do
          expect(subject).not_to allow_op_on_object(:read_env, service_instance)
        end

        it 'returns false for purge' do
          expect(subject).not_to allow_op_on_object(:purge, service_instance)
        end

        it 'does not allow the user to update the service' do
          expect(subject).not_to allow_op_on_object(:update, service_instance)
        end
      end

      context 'when the space of the service instance is not visible' do
        before do
          service_instance.space = nil
        end

        it_behaves_like 'read only access' do
          let(:object) { service_instance }
        end

        it 'does NOT allow the user to have manage permissions of the service instance' do
          expect(subject).not_to allow_op_on_object(:manage_permissions, service_instance)
        end

        it 'allows the user to have read permissions of the service instance' do
          expect(subject).to allow_op_on_object(:read_permissions, service_instance)
        end

        it 'does NOT allow the user to read default credentials of the service instance' do
          expect(subject).not_to allow_op_on_object(:read_env, service_instance)
        end

        it 'returns false for purge' do
          expect(subject).not_to allow_op_on_object(:purge, service_instance)
        end

        it 'does not allow the user to update the service' do
          expect(subject).not_to allow_op_on_object(:update, service_instance)
        end
      end
    end

    context 'organization manager (defensive)' do
      before { org.add_manager(user) }

      it_behaves_like 'read only access' do
        let(:object) { service_instance }
      end

      it 'does NOT allow the user to have manage permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:manage_permissions, service_instance)
      end

      it 'allows the user to have read permissions of the service instance' do
        expect(subject).to allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'organization billing manager (defensive)' do
      before { org.add_billing_manager(user) }

      it_behaves_like 'no access' do
        let(:object) { service_instance }
      end

      it 'does NOT allow the user to have manage permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:manage_permissions, service_instance)
      end

      it 'does NOT the user to have read permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'organization auditor (defensive)' do
      before { org.add_auditor(user) }

      it_behaves_like 'no access' do
        let(:object) { service_instance }
      end

      it 'does NOT allow the user to have manage permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:manage_permissions, service_instance)
      end

      it 'does NOT the user to have read permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:read_permissions, service_instance)
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

      it_behaves_like 'read only access' do
        let(:object) { service_instance }
      end

      it 'does NOT allow the user to have manage permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:manage_permissions, service_instance)
      end

      it 'allows the user to have read permissions of the service instance' do
        expect(subject).to allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'organization user (defensive)' do
      before { org.add_user(user) }

      it_behaves_like 'no access' do
        let(:object) { service_instance }
      end

      it 'does NOT allow the user to have manage permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:manage_permissions, service_instance)
      end

      it 'does NOT the user to have read permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:read_permissions, service_instance)
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

      it_behaves_like 'no access' do
        let(:object) { service_instance }
      end

      it 'does NOT allow the user to have manage permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:manage_permissions, service_instance)
      end

      it 'does NOT the user to have read permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:read_permissions, service_instance)
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

      it_behaves_like 'no access' do
        let(:object) { service_instance }
      end

      it 'does NOT allow the user to have manage permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:manage_permissions, service_instance)
      end

      it 'does NOT the user to have read permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:scopes) { [] }

      it_behaves_like 'no access' do
        let(:object) { service_instance }
      end

      it 'does NOT allow the user to have manage permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:manage_permissions, service_instance)
      end

      it 'does NOT the user to have read permissions of the service instance' do
        expect(subject).not_to allow_op_on_object(:read_permissions, service_instance)
      end

      it 'returns false for purge' do
        expect(subject).not_to allow_op_on_object(:purge, service_instance)
      end
    end

    describe 'a user with full org and space permissions using a client with limited scope' do
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
        let(:scopes) { ['cloud_controller.read'] }

        it_behaves_like 'read only access' do
          let(:object) { service_instance }
        end
        it { is_expected.to allow_op_on_object(:manage_permissions, service_instance) }
        it { is_expected.to allow_op_on_object(:read_permissions, service_instance) }
      end

      context 'with only cloud_controller_service_permissions.read scope' do
        let(:scopes) { ['cloud_controller_service_permissions.read'] }

        it 'allows the user to have manage permissions of the service instance' do
          expect(subject).to allow_op_on_object(:manage_permissions, service_instance)
        end

        it 'allows the user to have read permissions of the service instance' do
          expect(subject).to allow_op_on_object(:read_permissions, service_instance)
        end

        # All other actions are disallowed
        it_behaves_like 'no access' do
          let(:object) { service_instance }
        end
      end

      context 'with no cloud_controller scopes' do
        let(:scopes) { [] }

        it_behaves_like 'no access' do
          let(:object) { service_instance }
        end
        it { is_expected.not_to allow_op_on_object(:manage_permissions, service_instance) }
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
        let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space:) }

        it 'delegates to the UserProvidedServiceInstanceAccess' do
          expect_any_instance_of(UserProvidedServiceInstanceAccess).to receive(:allowed?).with(service_instance)
          subject.allowed?(service_instance)
        end
      end
    end
  end
end
