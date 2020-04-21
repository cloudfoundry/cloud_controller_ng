require 'spec_helper'
require 'messages/service_instance_show_message'
require 'field_message_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe ServiceInstanceShowMessage do
    it_behaves_like 'field query parameter', 'space', 'name,guid'

    it_behaves_like 'field query parameter', 'space.organization', 'name,guid'

    it_behaves_like 'field query parameter', 'service_plan', 'name,guid'

    it_behaves_like 'field query parameter', 'service_plan.service_offering', 'name,guid'

    it_behaves_like 'field query parameter', 'service_plan.service_offering.service_broker', 'name,guid'

    it 'does not accept fields resources that are not allowed' do
      message = described_class.from_params({ 'fields' => { 'space.foo': 'name' } })
      expect(message).not_to be_valid
      expect(message.errors[:fields]).to include(
        '[space.foo] valid resources are: ' \
        "'space', 'space.organization', 'service_plan', 'service_plan.service_offering', 'service_plan.service_offering.service_broker'"
      )
    end

    it 'does not accept other parameters' do
      message = described_class.from_params({ 'foobar' => 'pants' })
      expect(message).not_to be_valid
      expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
    end
  end
end
