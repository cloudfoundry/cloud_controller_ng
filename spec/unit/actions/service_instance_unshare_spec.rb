require 'spec_helper'
require 'actions/service_instance_unshare'

module VCAP::CloudController
  RSpec.describe ServiceInstanceUnshare do
    let(:service_instance_unshare) { ServiceInstanceUnshare.new }
    let(:service_instance) { ManagedServiceInstance.make }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: 'user-guid-1', user_email: 'user@email.com') }
    let(:target_space) { Space.make }
    let(:accepts_incomplete) { true }

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
          allow(ServiceBindingDelete).to receive(:new).with(user_audit_info, accepts_incomplete) { delete_binding_action }
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

        context 'when bindings have delete operations in progress' do
          let(:app_1) { AppModel.make(space: target_space, name: 'myapp1') }
          let(:app_2) { AppModel.make(space: target_space, name: 'myapp2') }
          let(:app_3) { AppModel.make(space: target_space, name: 'myapp3') }
          let(:service_binding_1) { ServiceBinding.make(app: app_1, service_instance: service_instance) }
          let(:service_binding_2) { ServiceBinding.make(app: app_2, service_instance: service_instance) }
          let(:service_binding_3) { ServiceBinding.make(app: app_3, service_instance: service_instance) }

          before do
            service_binding_1.service_binding_operation = ServiceBindingOperation.make(state: 'in progress', type: 'delete')
            service_binding_3.service_binding_operation = ServiceBindingOperation.make(state: 'in progress', type: 'delete')

            allow(ServiceBindingDelete).to receive(:new) { delete_binding_action }
            allow(delete_binding_action).to receive(:delete).and_return([[], []])
          end

          it 'unshares without deleting the binding' do
            expect { service_instance_unshare.unshare(service_instance, target_space, user_audit_info) }.
              to raise_error(VCAP::CloudController::ServiceInstanceUnshare::Error) do |err|
              expect(err.message).to include("\n\tThe binding between an application and service instance #{service_instance.name}" \
                                             " in space #{target_space.name} is being deleted asynchronously.")
            end
          end
        end

        context 'when a binding has operation in progress and the delete action fails' do
          before do
            err = StandardError.new('some-error')
            allow(delete_binding_action).to receive(:delete).with([service_binding]).and_return([err])

            service_binding.service_binding_operation = ServiceBindingOperation.make(state: 'in progress', type: 'delete')
          end

          it 'returns only the error from delete action' do
            expect { service_instance_unshare.unshare(service_instance, target_space, user_audit_info) }.to raise_error do |err|
              expect(err.message).to include('some-error')
              expect(err.message).not_to include("The binding between an application and service instance #{service_instance.name}" \
                                             " in space #{target_space.name} is being deleted asynchronously.")
            end
          end
        end
      end
    end

    context 'when bindings exist in the source space' do
      let(:app) { AppModel.make(space: service_instance.space, name: 'myapp') }
      let(:delete_binding_action) { instance_double(ServiceBindingDelete) }
      let(:service_binding) { ServiceBinding.make(app: app, service_instance: service_instance) }

      it 'unshares without deleting the binding' do
        allow(ServiceBindingDelete).to receive(:new).with(user_audit_info, accepts_incomplete) { delete_binding_action }
        allow(delete_binding_action).to receive(:delete).with([]).and_return([[], []])

        service_instance_unshare.unshare(service_instance, target_space, user_audit_info)
        expect(service_instance.shared_spaces).to be_empty
      end
    end
  end
end
