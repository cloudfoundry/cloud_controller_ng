require 'messages/metadata_base_message'
require 'messages/validators'
require 'messages/validators/maintenance_info_validator'

module VCAP::CloudController
  class ServiceInstanceUpdateManagedMessage < MetadataBaseMessage
    def self.relationships_requested?
      @relationships_requested ||= proc { |a| a.requested?(:relationships) }
    end

    register_allowed_keys [
      :name,
      :tags,
      :parameters,
      :relationships,
      :maintenance_info
    ]

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator, if: relationships_requested?

    validates :name, string: true, allow_nil: true
    validates :tags, array: true, allow_blank: true
    validate :tags_must_be_strings

    validates :parameters, hash: true, allow_nil: true
    validates :relationships, hash: true, allow_nil: true
    validates :maintenance_info, hash: true, allow_nil: true

    validates_with MaintenanceInfoValidator, if: ->(record) { record.maintenance_info.is_a? Hash }

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    def maintenance_info_message
      @maintenance_info_message ||= MaintenanceInfo.new(maintenance_info&.deep_symbolize_keys)
    end

    def updates
      updates = {}
      updates[:name] = name if requested?(:name)
      updates[:tags] = tags if requested?(:tags)
      updates[:service_plan_guid] = service_plan_guid if service_plan_guid
      updates
    end

    delegate :service_plan_guid, to: :relationships_message
    delegate :maintenance_info_version, to: :maintenance_info_message

    private

    def tags_must_be_strings
      if tags.present? && tags.is_a?(Array) && tags.any? { |i| !i.is_a?(String) }
        errors.add(:tags, 'must be a list of strings')
      end
    end

    class Relationships < BaseMessage
      register_allowed_keys [:service_plan]

      validates_with NoAdditionalKeysValidator

      validates :service_plan, presence: true, allow_nil: false, to_one_relationship: true

      def service_plan_guid
        HashUtils.dig(service_plan, :data, :guid)
      end
    end

    class MaintenanceInfo < BaseMessage
      register_allowed_keys [:version]

      validates_with NoAdditionalKeysValidator

      validates :version, string: true, allow_nil: true, semver: true

      def maintenance_info_version
        version
      end
    end
  end
end
