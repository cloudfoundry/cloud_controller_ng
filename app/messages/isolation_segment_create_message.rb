require 'messages/isolation_segment_update_message'

module VCAP::CloudController
  class IsolationSegmentCreateMessage < IsolationSegmentUpdateMessage
    validates :name, presence: true
  end
end
