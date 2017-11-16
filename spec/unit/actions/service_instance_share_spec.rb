require 'spec_helper'
require 'actions/service_instance_share'

module VCAP::CloudController
  RSpec.describe ServiceInstanceShare do
    let(:service_instance_share) { ServiceInstanceShare.new }
    let(:service_instance) { ManagedServiceInstance.make }
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

      context 'when the service does is not shareable' do
        before do
          allow(service_instance).to receive(:shareable?).and_return(false)
        end

        it 'raises an api error' do
          expect {
            service_instance_share.create(service_instance, [target_space1, target_space2], user_audit_info)
          }.to raise_error(CloudController::Errors::ApiError, /The #{service_instance.service.label} service does not support service instance sharing./)
        end
      end
    end
  end
end
