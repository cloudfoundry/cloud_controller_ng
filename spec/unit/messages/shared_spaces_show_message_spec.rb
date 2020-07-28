require 'spec_helper'
require 'messages/shared_spaces_show_message'
require 'field_message_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe SharedSpacesShowMessage do
    it_behaves_like 'field query parameter', 'space', 'name,guid,relationships.organization'

    it_behaves_like 'field query parameter', 'space.organization', 'name,guid'

    it_behaves_like 'fields query hash'
  end
end
