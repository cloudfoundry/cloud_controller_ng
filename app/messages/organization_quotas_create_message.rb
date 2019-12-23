require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class OrganizationQuotasCreateMessage < BaseMessage
    MAX_ORGANIZATION_QUOTA_NAME_LENGTH = 250

    def self.relationships_requested?
      @relationships_requested ||= proc { |a| a.requested?(:relationships) }
    end

    register_allowed_keys [:name, :apps, :relationships]
    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator, if: relationships_requested?

    validates :name,
      string: true,
      presence: true,
      allow_nil: false,
      length: { maximum: MAX_ORGANIZATION_QUOTA_NAME_LENGTH }

    validate :apps_validator

    delegate :total_memory_in_mb, :per_process_memory_in_mb, :total_instances, :per_app_tasks, to: :apps_limits_message

    def apps_validator
      errors[:apps].concat(apps_limits_message.errors.full_messages) unless apps_limits_message.valid?
    end

    def apps_limits_message
      @apps_limits_message ||= AppsLimitsMessage.new(apps&.deep_symbolize_keys)
    end

    delegate :organization_guids, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end
  end

  class AppsLimitsMessage < BaseMessage
    register_allowed_keys [:total_memory_in_mb, :per_process_memory_in_mb, :total_instances, :per_app_tasks]

    validates_with NoAdditionalKeysValidator

    validates :total_memory_in_mb,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true

    validates :per_process_memory_in_mb,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true

    validates :total_instances,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true

    validates :per_app_tasks,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true
  end

  class Relationships < BaseMessage
    register_allowed_keys [:organizations]

    validates :organizations, allow_nil: true, to_many_relationship: true

    def initialize(params)
      super(params)
    end

    def organization_guids
      orgs = HashUtils.dig(organizations, :data)
      orgs ? orgs.map { |org| org[:guid] } : []
    end
  end
end
