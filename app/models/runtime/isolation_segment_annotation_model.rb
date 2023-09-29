module VCAP::CloudController
  class IsolationSegmentAnnotationModel < Sequel::Model(:isolation_segment_annotations_migration_view)
    set_primary_key :id
    many_to_one :isolation_segment,
                class: 'VCAP::CloudController::IsolationSegment',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
