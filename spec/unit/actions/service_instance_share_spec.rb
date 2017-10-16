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
    end
  end
end
