require 'messages/base_message'
require 'messages/buildpack_lifecycle_data_message'
require 'messages/validators/metadata_validator'

module VCAP::CloudController
  class AppCreateMessage < BaseMessage
    register_allowed_keys [:name, :environment_variables, :relationships, :lifecycle, :metadata]

    def self.lifecycle_requested?
      @lifecycle_requested ||= proc { |a| a.requested?(:lifecycle) }
    end

    def self.metadata_requested?
      @metadata_requested ||= proc { |a| a.requested?(:metadata) }
    end

    validates_with NoAdditionalKeysValidator, RelationshipValidator
    validates_with LifecycleValidator, if: lifecycle_requested?
    validates_with MetadataValidator, if: metadata_requested?

    validates :name, string: true
    validates :environment_variables, hash: true, allow_nil: true

    validates :lifecycle_type,
      string: true,
      if: lifecycle_requested?

    validates :lifecycle_data,
      hash: true,
      allow_nil: false,
      if: lifecycle_requested?

    delegate :space_guid, to: :relationships_message

    def labels
      HashUtils.dig(metadata, :labels)
    end

    def lifecycle_type
      HashUtils.dig(lifecycle, :type)
    end

    def lifecycle_data
      HashUtils.dig(lifecycle, :data)
    end

    def buildpack_data
      @buildpack_data ||= BuildpackLifecycleDataMessage.new(lifecycle_data)
    end

    def relationships_message
      @relationships_message ||= Relationships.new(relationships.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:space]

      validates_with NoAdditionalKeysValidator

      validates :space, presence: true, allow_nil: false, to_one_relationship: true

      def space_guid
        HashUtils.dig(space, :data, :guid)
      end
    end
  end
end
