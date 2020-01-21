require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class SpaceQuotasCreateMessage < BaseMessage
    MAX_SPACE_QUOTA_NAME_LENGTH = 250

    def self.key_requested?(key)
      proc { |a| a.requested?(key) }
    end

    register_allowed_keys [:name, :relationships, :apps]
    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator

    validates :name,
      string: true,
      presence: true,
      length: { maximum: MAX_SPACE_QUOTA_NAME_LENGTH }

    validate :apps_validator, if: key_requested?(:apps)

    # Apps validations
    delegate :total_memory_in_mb, :per_process_memory_in_mb, :total_instances, :per_app_tasks, to: :apps_limits_message

    def validates_hash(key, sym)
      return true if key.is_a?(Hash)

      errors[sym].concat(['must be an object'])
      false
    end

    def apps_validator
      return unless validates_hash(apps, :apps)

      errors[:apps].concat(apps_limits_message.errors.full_messages) unless apps_limits_message.valid?
    end

    def apps_limits_message
      @apps_limits_message ||= QuotasAppsMessage.new(apps&.deep_symbolize_keys)
    end

    # Relationships validations
    delegate :organization_guid, to: :relationships_message
    delegate :space_guids, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:organization, :spaces]

      validates :organization, allow_nil: false, to_one_relationship: true
      validates :spaces, allow_nil: true, to_many_relationship: true

      def initialize(params)
        super(params)
      end

      def organization_guid
        HashUtils.dig(organization, :data, :guid)
      end

      def space_guids
        space_data = HashUtils.dig(spaces, :data)
        space_data ? space_data.map { |space| space[:guid] } : []
      end
    end
  end
end
