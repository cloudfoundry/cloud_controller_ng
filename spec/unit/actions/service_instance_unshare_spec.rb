require 'spec_helper'
require 'actions/service_instance_share'

module VCAP::CloudController
  RSpec.describe ServiceInstanceUnshare do
    let(:service_instance_unshare) { ServiceInstanceUnshare.new }
    let(:service_instance) { ManagedServiceInstance.make }
    let(:target_space) { Space.make }

    before do
      service_instance.add_shared_space(target_space)
      expect(service_instance.shared_spaces).not_to be_empty
    end

    describe '#unshare' do
      it 'removes the share' do
        service_instance_unshare.unshare(service_instance, target_space)
        expect(service_instance.shared_spaces).to be_empty
      end
    end
  end
end
