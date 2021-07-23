require 'spec_helper'
require 'actions/service_instance_share'

module VCAP::CloudController
  RSpec.describe ServiceInstanceShare do
    let(:service_instance_share) { ServiceInstanceShare.new }
    let(:service_instance) { ManagedServiceInstance.make }
    let(:user_provided_service_instance) { UserProvidedServiceInstance.make }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: 'user-guid-1', user_email: 'user@email.com') }
    let(:target_space1) { Space.make }
    let(:target_space2) { Space.make }

    describe '#create' do
      it 'creates share' do
        shared_instance = service_instance_share.create(service_instance, [target_space1, target_space2], user_audit_info)

        expect(shared_instance.shared_spaces.length).to eq 2

        expect(target_space1.service_instances_shared_from_other_spaces.length).to eq 1
        expect(target_space2.service_instances_shared_from_other_spaces.length).to eq 1

        expect(target_space1.service_instances_shared_from_other_spaces[0]).to eq service_instance
        expect(target_space2.service_instances_shared_from_other_spaces[0]).to eq service_instance
      end

      it 'records a share event' do
        allow(Repositories::ServiceInstanceShareEventRepository).to receive(:record_share_event)

        service_instance_share.create(service_instance, [target_space1, target_space2], user_audit_info)
        expect(Repositories::ServiceInstanceShareEventRepository).to have_received(:record_share_event).with(
          service_instance, [target_space1.guid, target_space2.guid], user_audit_info)
      end

      context 'when a share already exists' do
        before do
          service_instance.add_shared_space(target_space1)
        end

        it 'is idempotent' do
          shared_instance = service_instance_share.create(service_instance, [target_space1], user_audit_info)
          expect(shared_instance.shared_spaces.length).to eq 1
        end
      end

      context 'when sharing one space from the list of spaces fails' do
        before do
          allow(service_instance).to receive(:add_shared_space).with(target_space1).and_call_original
          allow(service_instance).to receive(:add_shared_space).with(target_space2).and_raise('db failure')
        end

        it 'does not share with any spaces' do
          expect {
            service_instance_share.create(service_instance, [target_space1, target_space2], user_audit_info)
          }.to raise_error('db failure')

          instance = ServiceInstance.find(guid: service_instance.guid)

          expect(instance.shared_spaces.length).to eq 0
        end

        it 'does not audit any share events' do
          expect(Repositories::ServiceInstanceShareEventRepository).to_not receive(:record_share_event)

          expect {
            service_instance_share.create(service_instance, [target_space1, target_space2], user_audit_info)
          }.to raise_error('db failure')
        end
      end

      context 'when source space is included in list of target spaces' do
        it 'does not share with any spaces' do
          expect {
            service_instance_share.create(service_instance, [target_space1, service_instance.space], user_audit_info)
          }.to raise_error(VCAP::CloudController::ServiceInstanceShare::Error, 'Service instances cannot be shared into the space where they were created.')

          instance = ServiceInstance.find(guid: service_instance.guid)

          expect(instance.shared_spaces.length).to eq 0
        end

        it 'does not audit any share events' do
          expect(Repositories::ServiceInstanceShareEventRepository).to_not receive(:record_share_event)

          expect {
            service_instance_share.create(service_instance, [target_space1, service_instance.space], user_audit_info)
          }.to raise_error(VCAP::CloudController::ServiceInstanceShare::Error, 'Service instances cannot be shared into the space where they were created.')
        end
      end

      context 'when the service instance is not shareable' do
        before do
          allow(service_instance).to receive(:shareable?).and_return(false)
        end

        it 'raises an api error' do
          expect {
            service_instance_share.create(service_instance, [target_space1, target_space2], user_audit_info)
          }.to raise_error(VCAP::CloudController::ServiceInstanceShare::Error, /The #{service_instance.service.label} service does not support service instance sharing./)
        end
      end

      context 'when a service instance already exists in the target space with the same name as the service being shared' do
        let(:service_instance) { ManagedServiceInstance.make(name: 'banana') }
        let!(:target_space_service_instance) { ManagedServiceInstance.make(name: 'banana', space: target_space1) }

        it 'raises an api error' do
          expect {
            service_instance_share.create(service_instance, [target_space1], user_audit_info)
          }.to raise_error(VCAP::CloudController::ServiceInstanceShare::Error, /A service instance called #{service_instance.name} already exists in #{target_space1.name}/)
          expect(service_instance.shared_spaces).to be_empty
        end
      end

      context 'when the service is user-provided' do
        it 'raises an api error' do
          expect {
            service_instance_share.create(user_provided_service_instance, [target_space1, target_space2], user_audit_info)
          }.to raise_error(VCAP::CloudController::ServiceInstanceShare::Error, /User-provided services cannot be shared/)
        end
      end

      context 'when the service is a route service' do
        context 'and is a managed instance' do
          before do
            allow(service_instance).to receive(:route_service?).and_return(true)
          end

          it 'raises an api error' do
            expect {
              service_instance_share.create(service_instance, [target_space1, target_space2], user_audit_info)
            }.to raise_error(VCAP::CloudController::ServiceInstanceShare::Error, /Route services cannot be shared/)
          end
        end

        context 'and is a user-provided service instance' do
          before do
            allow(user_provided_service_instance).to receive(:route_service?).and_return(true)
          end

          it 'raises an api error' do
            expect {
              service_instance_share.create(user_provided_service_instance, [target_space1, target_space2], user_audit_info)
            }.to raise_error(VCAP::CloudController::ServiceInstanceShare::Error, /Route services cannot be shared/)
          end
        end
      end

      context 'when the service plan is inactive' do
        let(:service_plan) { ServicePlan.make(active: false, name: 'service-plan-name') }
        let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }

        it 'raises an api error' do
          error_msg = 'The service instance could not be shared as the service-plan-name plan is inactive.'
          expect {
            service_instance_share.create(service_instance, [target_space1], user_audit_info)
          }.to raise_error(VCAP::CloudController::ServiceInstanceShare::Error, error_msg)
        end
      end

      context 'when the service plan is from a private space-scoped broker' do
        let(:source_org) { Organization.make(name: 'source-org') }
        let(:source_space) { Space.make(name: 'source-space', organization: source_org) }
        let(:broker) { ServiceBroker.make(space: source_space) }
        let(:service) { Service.make(service_broker: broker, label: 'space-scoped-service') }
        let(:service_plan) { ServicePlan.make(service: service, name: 'my-plan') }
        let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
        let(:target_space1) { Space.make(name: 'target-space', organization: source_org) }

        it 'raises an api error' do
          error_msg = 'Access to service space-scoped-service and plan my-plan is not enabled in source-org/target-space.'
          expect {
            service_instance_share.create(service_instance, [target_space1], user_audit_info)
          }.to raise_error(VCAP::CloudController::ServiceInstanceShare::Error, error_msg)
        end
      end

      context 'when the service plan is not public' do
        let(:service_plan) { ServicePlan.make(public: false) }
        let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }

        it 'raises an api error if service access disabled in both source and target' do
          error_msg = "Access to service #{service_instance.service.label} and plan #{service_instance.service_plan.name} is not " \
            "enabled in #{target_space1.organization.name}/#{target_space1.name}."
          expect {
            service_instance_share.create(service_instance, [target_space1], user_audit_info)
          }.to raise_error(VCAP::CloudController::ServiceInstanceShare::Error, error_msg)
        end

        context 'and when the source org has service plan access enabled but the target org has service plan access disabled' do
          let(:source_org) { Organization.make }
          let(:space) { Space.make(organization: source_org) }
          let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan, space: space) }

          before do
            ServicePlanVisibility.make(organization: source_org, service_plan: service_instance.service_plan)
          end

          it 'raises an api error' do
            error_msg = "Access to service #{service_instance.service.label} and plan #{service_instance.service_plan.name} is not " \
              "enabled in #{target_space1.organization.name}/#{target_space1.name}."
            expect {
              service_instance_share.create(service_instance, [target_space1], user_audit_info)
            }.to raise_error(VCAP::CloudController::ServiceInstanceShare::Error, error_msg)
          end
        end

        context 'and when the source org has service plan access disabled but the target org has service plan access enabled' do
          let(:source_org) { Organization.make }
          let(:space) { Space.make(organization: source_org) }
          let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan, space: space) }

          before do
            ServicePlanVisibility.make(organization: target_space1.organization, service_plan: service_instance.service_plan)
          end

          it 'creates the share' do
            shared_instance = service_instance_share.create(service_instance, [target_space1], user_audit_info)
            expect(shared_instance.shared_spaces.length).to eq 1
          end
        end

        context 'and when source org has had service plan access enabled and the target org has service plan access enabled' do
          let(:source_org) { Organization.make }
          let(:space) { Space.make(organization: source_org) }
          let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan, space: space) }

          before do
            ServicePlanVisibility.make(organization: target_space1.organization, service_plan: service_instance.service_plan)
            ServicePlanVisibility.make(organization: source_org, service_plan: service_instance.service_plan)
          end

          it 'creates the share' do
            shared_instance = service_instance_share.create(service_instance, [target_space1], user_audit_info)
            expect(shared_instance.shared_spaces.length).to eq 1
          end
        end
      end
    end
  end
end
