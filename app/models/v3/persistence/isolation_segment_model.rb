module VCAP::CloudController
  class IsolationSegmentModel < Sequel::Model(:isolation_segments)
    SHARED_ISOLATION_SEGMENT_GUID = '933b4c58-120b-499a-b85d-4b6fc9e2903b'.freeze

    include Serializer
    ISOLATION_SEGMENT_MODEL_REGEX = /\A[[:print:]]+\Z/

    one_to_many :spaces,
      key: :isolation_segment_guid,
      primary_key: :guid

    many_to_many :organizations,
      left_key: :isolation_segment_guid,
      left_primary_key: :guid,
      right_key: :organization_guid,
      right_primary_key: :guid,
      join_table: :organizations_isolation_segments, without_guid_generation: true

    def validate
      validates_format ISOLATION_SEGMENT_MODEL_REGEX, :name, message: Sequel.lit('Isolation Segment names can only contain non-blank unicode characters')

      validates_unique [:name], message: Sequel.lit('Isolation Segment names are case insensitive and must be unique')
    end

    def before_destroy
      raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'space', 'isolation segment') unless spaces.empty?
      raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'Organization', 'Isolation Segment') unless organizations.empty?
      super
    end
  end
end
