require 'spec_helper'
require 'actions/service_instance_unshare'

module VCAP::CloudController
  RSpec.describe ServiceInstanceUnshare do
    let(:service_instance_unshare) { ServiceInstanceUnshare.new }
    let(:service_instance) { create(:managed_service_instance) }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: 'user-guid-1', user_email: 'user@email.com') }
    let(:target_space) { create(:space) }
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
          service_instance, target_space.guid, user_audit_info
        )
      end

      context 'when the service plan is inactive' do
        let(:service_plan) { create(:service_plan, active: false) }
        let(:service_instance) { create(:managed_service_instance, service_plan:) }

        it 'unshares successfully' do
          service_instance_unshare.unshare(service_instance, target_space, user_audit_info)
          expect(service_instance.shared_spaces).to be_empty
        end
      end

      context 'when bindings exist in the target space' do
        let(:app) { create(:app_model, space: target_space, name: 'myapp') }
        let(:delete_binding_action) { instance_double(V3::ServiceCredentialBindingDelete) }
        let(:service_binding) { create(:service_binding, app:, service_instance:) }

        before do
          allow(V3::ServiceCredentialBindingDelete).to receive(:new).with(:credential, user_audit_info) { delete_binding_action }
        end

        it 'deletes bindings and unshares' do
          allow(delete_binding_action).to receive(:delete).with(service_binding).and_return({ finished: true })

          service_instance_unshare.unshare(service_instance, target_space, user_audit_info)
          expect(service_instance.shared_spaces).to be_empty
        end

        context 'when an unbind fails' do
          it 'does not unshare' do
            err = StandardError.new('oops')
            allow(delete_binding_action).to receive(:delete).with(service_binding).and_raise(err)

            expect { service_instance_unshare.unshare(service_instance, target_space, user_audit_info) }.to raise_error(VCAP::CloudController::ServiceInstanceUnshare::Error)
            expect(service_instance.shared_spaces).not_to be_empty
          end
        end

        context 'when bindings have delete operations in progress' do
          let!(:app_1) { create(:app_model, space: target_space, name: 'myapp1') }
          let!(:app_2) { create(:app_model, space: target_space, name: 'myapp2') }
          let!(:app_3) { create(:app_model, space: target_space, name: 'myapp3') }
          let!(:service_binding_1) { create(:service_binding, app: app_1, service_instance: service_instance) }
          let!(:service_binding_2) { create(:service_binding, app: app_2, service_instance: service_instance) }
          let!(:service_binding_3) { create(:service_binding, app: app_3, service_instance: service_instance) }

          before do
            allow(delete_binding_action).to receive(:delete).and_return({ finished: false })
          end

          it 'fails to unshare' do
            expect { service_instance_unshare.unshare(service_instance, target_space, user_audit_info) }.
              to raise_error(VCAP::CloudController::ServiceInstanceUnshare::Error) do |err|
              expect(err.message).to include("\n\tThe binding between an application and service instance #{service_instance.name} " \
                                             "in space #{target_space.name} is being deleted asynchronously.")
            end

            expect(service_instance.shared_spaces).to include(target_space)
          end

          it 'enqueues jobs to poll the delete operations' do
            expect { service_instance_unshare.unshare(service_instance, target_space, user_audit_info) }.
              to raise_error(VCAP::CloudController::ServiceInstanceUnshare::Error)

            binding_guids = [service_binding_1.guid, service_binding_2.guid, service_binding_3.guid]
            jobs = VCAP::CloudController::PollableJobModel.where(resource_guid: binding_guids)
            expect(jobs.count).to eq(3)
          end
        end

        context 'when a binding has operation in progress and the delete action fails' do
          before do
            err = StandardError.new('some-error')
            allow(delete_binding_action).to receive(:delete).with(service_binding).and_raise(err)

            service_binding.service_binding_operation = create(:service_binding_operation, state: 'in progress', type: 'delete')
          end

          it 'returns only the error from delete action' do
            expect { service_instance_unshare.unshare(service_instance, target_space, user_audit_info) }.to raise_error do |err|
              expect(err.message).to include('some-error')
              expect(err.message).not_to include("The binding between an application and service instance #{service_instance.name} " \
                                                 "in space #{target_space.name} is being deleted asynchronously.")
            end
          end
        end
      end
    end

    context 'when bindings exist in the source space' do
      let(:app) { create(:app_model, space: service_instance.space, name: 'myapp') }
      let(:delete_binding_action) { instance_double(ServiceBindingDelete) }
      let(:service_binding) { create(:service_binding, app:, service_instance:) }

      it 'unshares without deleting the binding' do
        allow(ServiceBindingDelete).to receive(:new).with(user_audit_info, accepts_incomplete) { delete_binding_action }
        allow(delete_binding_action).to receive(:delete).with([]).and_return([[], []])

        service_instance_unshare.unshare(service_instance, target_space, user_audit_info)
        expect(service_instance.shared_spaces).to be_empty
      end
    end
  end
end
