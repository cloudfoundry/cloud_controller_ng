require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class OrganizationQuotasCreateMessage < BaseMessage
    MAX_ORGANIZATION_QUOTA_NAME_LENGTH = 250

    def self.relationships_requested?
      @relationships_requested ||= proc { |a| a.requested?(:relationships) }
    end

    register_allowed_keys [:name, :total_memory_in_mb, :paid_services_allowed, :total_service_instances, :total_routes, :relationships]
    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator, if: relationships_requested?

    validates :name,
      string: true,
      presence: true,
      allow_nil: false,
      length: { maximum: MAX_ORGANIZATION_QUOTA_NAME_LENGTH }

    validates :total_memory_in_mb,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true

    validates :total_service_instances,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true

    validates :total_routes,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true

    validates :paid_services_allowed,
      inclusion: { in: [true, false], message: 'must be a boolean' },
      allow_nil: true

    delegate :organization_guids, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
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
end
