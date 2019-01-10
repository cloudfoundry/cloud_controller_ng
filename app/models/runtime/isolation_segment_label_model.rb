module VCAP::CloudController
  class IsolationSegmentLabelModel < Sequel::Model(:isolation_segment_labels)
    many_to_one :isolation_segment,
      class: 'VCAP::CloudController::IsolationSegment',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
