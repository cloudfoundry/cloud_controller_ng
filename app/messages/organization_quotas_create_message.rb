require 'messages/organization_quotas_update_message'
require 'messages/validators'

module VCAP::CloudController
  class OrganizationQuotasCreateMessage < OrganizationQuotasUpdateMessage
    register_allowed_keys [:relationships]

    validates_with RelationshipValidator, if: key_requested?(:relationships)

    validates :name, presence: true

    # Relationships validations
    delegate :organization_guids, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end
  end

  class Relationships < BaseMessage
    register_allowed_keys [:organizations]

    validates :organizations, allow_nil: true, to_many_relationship: true

    def organization_guids
      orgs = HashUtils.dig(organizations, :data)
      orgs ? orgs.map { |org| org[:guid] } : []
    end
  end
end
