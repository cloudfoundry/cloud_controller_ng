require 'spec_helper'
require 'messages/service_instance_show_message'
require 'field_message_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe ServiceInstanceShowMessage do
    it_behaves_like 'field query parameter', 'space', 'name,guid'

    it_behaves_like 'field query parameter', 'space.organization', 'name,guid'

    it_behaves_like 'field query parameter', 'service_plan', 'name,guid'

    it_behaves_like 'field query parameter', 'service_plan.service_offering', 'name,guid,description,tags,documentation_url'

    it_behaves_like 'field query parameter', 'service_plan.service_offering.service_broker', 'name,guid'

    it_behaves_like 'fields query hash'
  end
end
