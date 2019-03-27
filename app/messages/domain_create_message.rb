require 'messages/metadata_base_message'

module VCAP::CloudController
  class DomainCreateMessage < MetadataBaseMessage
    # The maximum fully-qualified domain length is 255 including separators, but this includes two "invisible"
    # characters at the beginning and end of the domain, so for string comparisons, the correct length is 253.
    #
    # The first character denotes the length of the first label, and the last character denotes the termination
    # of the domain.
    MAXIMUM_FQDN_DOMAIN_LENGTH = 253
    MAXIMUM_DOMAIN_LABEL_LENGTH = 63
    MINIMUM_FQDN_DOMAIN_LENGTH = 3

    register_allowed_keys [
      :name,
      :internal,
      :relationships
    ]

    def self.relationships_requested?
      @relationships_requested ||= proc { |a| a.requested?(:relationships) }
    end

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator, if: relationships_requested?

    validates :name,
      presence: true,
      string: true,
      length: {
        minimum: MINIMUM_FQDN_DOMAIN_LENGTH,
        maximum: MAXIMUM_FQDN_DOMAIN_LENGTH,
      },
      format: {
        with: CloudController::DomainDecorator::DOMAIN_REGEX,
        message: 'does not comply with RFC 1035 standards',
      }

    validates :name,
      format: {
        with: /\./.freeze,
        message: 'must contain at least one "."',
      }

    validates :name,
      format: {
        with: /\A((.{0,63})\.)?+(.{0,63})\Z/,
        message: 'subdomains must each be at most 63 characters',
      }

    validate :alpha_numeric

    validate :mutually_exclusive_organization_and_internal

    validates :internal,
      allow_nil: true,
      boolean: true

    delegate :organization_guid, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:organization]

      validates_with NoAdditionalKeysValidator
      validates_with ToOneRelationshipValidator, attributes: [:organization]

      def organization_guid
        HashUtils.dig(organization, :data, :guid)
      end
    end

    private

    def alpha_numeric
      if /[^a-z0-9\-\.]/i.match?(name.to_s)
        errors.add(:name, 'must consist of alphanumeric characters and hyphens')
      end
    end

    def mutually_exclusive_organization_and_internal
      if requested?(:internal) && requested?(:relationships)
        errors.add(:base, 'Can not associate an internal domain with an organization')
      end
    end
  end
end
