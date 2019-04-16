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
    delegate :shared_organizations_guids, to: :relationships_message

    def relationships_message
      # need the & instaed of doing if requested(rel..) because we can't delegate if rl_msg nil
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
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

    class Relationships < BaseMessage
      def self.shared_organizations_requested?
        @shared_organizations_requested ||= proc { |a| a.requested?(:shared_organizations) }
      end

      def self.organization_requested?
        @organization_requested ||= proc { |a| a.requested?(:organization) }
      end

      register_allowed_keys [:organization, :shared_organizations]

      validates_with NoAdditionalKeysValidator
      validates :organization, allow_nil: true, to_one_relationship: true
      validates :shared_organizations, allow_nil: true, to_many_relationship: true

      validate :valid_organization_if_shared_organizations, if: shared_organizations_requested?

      def organization_guid
        HashUtils.dig(organization, :data, :guid)
      end

      def shared_organizations_guids
        shared_orgs = HashUtils.dig(shared_organizations, :data)
        shared_orgs ? shared_orgs.map { |hsh| hsh[:guid] } : []
      end

      def valid_organization_if_shared_organizations
        if !requested?(:organization)
          errors.add(:base, 'cannot contain shared_organizations without an owning organization.')
        end
      end
    end
  end
end
