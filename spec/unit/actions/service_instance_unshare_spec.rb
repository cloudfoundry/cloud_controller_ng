require 'spec_helper'
require 'actions/service_instance_unshare'

module VCAP::CloudController
  RSpec.describe ServiceInstanceUnshare do
    let(:service_instance_unshare) { ServiceInstanceUnshare.new }
    let(:service_instance) { ManagedServiceInstance.make }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: 'user-guid-1', user_email: 'user@email.com') }
    let(:target_space) { Space.make }

    before do
      service_instance.add_shared_space(target_space)
      expect(service_instance.shared_spaces).not_to be_empty
    end

    describe '#unshare' do
      it 'removes the share' do
        service_instance_unshare.unshare(service_instance, target_space, user_audit_info)
        expect(service_instance.shared_spaces).to be_empty
      end

      it 'records an unshare event' do
        allow(Repositories::ServiceInstanceShareEventRepository).to receive(:record_unshare_event)

        service_instance_unshare.unshare(service_instance, target_space, user_audit_info)
        expect(Repositories::ServiceInstanceShareEventRepository).to have_received(:record_unshare_event).with(
          service_instance, target_space.guid, user_audit_info)
      end

      context 'when the service plan is inactive' do
        let(:service_plan) { ServicePlan.make(active: false) }
        let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }

        it 'unshares successfully' do
          service_instance_unshare.unshare(service_instance, target_space, user_audit_info)
          expect(service_instance.shared_spaces).to be_empty
        end
      end

      context 'when bindings exist in the target space' do
        let(:app) { AppModel.make(space: target_space, name: 'myapp') }
        let(:delete_binding_action) { instance_double(ServiceBindingDelete) }
        let(:service_binding) { ServiceBinding.make(app: app, service_instance: service_instance) }

        before do
          allow(ServiceBindingDelete).to receive(:new) { delete_binding_action }
        end

        it 'deletes bindings and unshares' do
          allow(delete_binding_action).to receive(:delete).with([service_binding]).and_return([[], []])

          service_instance_unshare.unshare(service_instance, target_space, user_audit_info)
          expect(service_instance.shared_spaces).to be_empty
        end

        context 'when an unbind fails' do
          it 'does not unshare' do
            err = StandardError.new('oops')
            allow(delete_binding_action).to receive(:delete).with([service_binding]).and_return([[err], []])

            expect { service_instance_unshare.unshare(service_instance, target_space, user_audit_info) }.to raise_error(VCAP::CloudController::ServiceInstanceUnshare::Error)
            expect(service_instance.shared_spaces).to_not be_empty
          end
        end
      end

      context 'when bindings exist in the source space' do
        let(:app) { AppModel.make(space: service_instance.space, name: 'myapp') }
        let(:delete_binding_action) { instance_double(ServiceBindingDelete) }
        let(:service_binding) { ServiceBinding.make(app: app, service_instance: service_instance) }

        it 'unshares without deleting the binding' do
          allow(ServiceBindingDelete).to receive(:new) { delete_binding_action }
          allow(delete_binding_action).to receive(:delete).with([]).and_return([[], []])

          service_instance_unshare.unshare(service_instance, target_space, user_audit_info)
          expect(service_instance.shared_spaces).to be_empty
        end
      end
    end
  end
end
