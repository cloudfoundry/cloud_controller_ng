module VCAP::CloudController
  class IsolationSegmentAnnotationModel < Sequel::Model(:isolation_segment_annotations)
    many_to_one :isolation_segment,
      class: 'VCAP::CloudController::IsolationSegment',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
