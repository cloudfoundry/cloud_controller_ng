require 'messages/metadata_base_message'
require 'messages/buildpack_lifecycle_data_message'

module VCAP::CloudController
  class AppCreateMessage < MetadataBaseMessage
    register_allowed_keys [:name, :environment_variables, :relationships, :lifecycle]

    def self.lifecycle_requested?
      @lifecycle_requested ||= proc { |a| a.requested?(:lifecycle) }
    end

    def self.lifecycle_type_requested?
      @lifecycle_type_requested ||= proc { |a| a.requested?(:lifecycle) && a.lifecycle_type.present? }
    end

    validates_with NoAdditionalKeysValidator, RelationshipValidator
    validates_with LifecycleValidator, if: lifecycle_type_requested?

    validates :name, string: true
    validates :environment_variables, hash: true, allow_nil: true

    validates :lifecycle_type,
      string: true,
      if: lifecycle_type_requested?

    validates :lifecycle_data,
      hash: true,
      allow_nil: false,
      if: lifecycle_requested?

    delegate :space_guid, to: :relationships_message

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
