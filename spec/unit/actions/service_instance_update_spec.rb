require 'spec_helper'
require 'actions/service_instance_update'

module VCAP::CloudController
  RSpec.describe ServiceInstanceUpdate do
    describe '#update' do
      let(:body) do
        {
          metadata: {
            labels: {
              freaky: 'wednesday',
            },
            annotations: {
              tokyo: 'grapes'
            },
          },
        }
      end
      let(:service_instance) { ServiceInstance.make }
      let(:message) { ServiceInstanceUpdateMessage.new(body) }

      it 'updates the service_instance metadata' do
        expect(message).to be_valid
        ServiceInstanceUpdate.update(service_instance, message)

        service_instance.reload
        expect(service_instance.labels.map { |label| { key: label.key_name, value: label.value } }).to match_array([{ key: 'freaky', value: 'wednesday' }])
        expect(service_instance.annotations.map { |a| { key: a.key, value: a.value } }).
          to match_array([{ key: 'tokyo', value: 'grapes' }])
      end
    end
  end
end
