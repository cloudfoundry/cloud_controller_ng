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
    end
  end
end
