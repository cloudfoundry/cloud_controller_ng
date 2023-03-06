module VCAP::CloudController
  class IsolationSegmentModel < Sequel::Model(:isolation_segments)
    SHARED_ISOLATION_SEGMENT_GUID = '933b4c58-120b-499a-b85d-4b6fc9e2903b'.freeze

    include Serializer
    ISOLATION_SEGMENT_MODEL_REGEX = /\A[[:print:]]+\Z/

    one_to_many :spaces, key: :isolation_segment_guid, primary_key: :guid
    one_to_many :labels, class: 'VCAP::CloudController::IsolationSegmentLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::IsolationSegmentAnnotationModel', key: :resource_guid, primary_key: :guid

    many_to_many :organizations,
      left_key: :isolation_segment_guid,
      left_primary_key: :guid,
      right_key: :organization_guid,
      right_primary_key: :guid,
      join_table: :organizations_isolation_segments, without_guid_generation: true

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    def validate
      validates_format ISOLATION_SEGMENT_MODEL_REGEX, :name, message: Sequel.lit('Isolation Segment names can only contain non-blank unicode characters')

      validates_unique [:name], message: Sequel.lit('Isolation Segment names are case insensitive and must be unique')
    end

    def is_shared_segment?
      guid == SHARED_ISOLATION_SEGMENT_GUID
    end
  end
end
