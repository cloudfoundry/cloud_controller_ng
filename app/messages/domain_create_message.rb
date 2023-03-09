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
      :relationships,
      :router_group
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
        with: /\./,
        message: 'must contain at least one "."',
      }

    validates :name,
      format: {
        with: /\A^([^\.]{0,63}\.)*[^\.]{0,63}$\Z/,
        message: 'subdomains must each be at most 63 characters',
      }

    validate :alpha_numeric

    validate :router_group_validation

    validate :mutually_exclusive_fields

    validates :internal,
      allow_nil: true,
      boolean: true

    delegate :organization_guid, to: :relationships_message
    delegate :shared_organizations_guids, to: :relationships_message

    def relationships_message
      # need the & instaed of doing if requested(rel..) because we can't delegate if rl_msg nil
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    def router_group_guid
      HashUtils.dig(router_group, :guid)
    end

    private

    def alpha_numeric
      if /[^a-z0-9\-\.]/i.match?(name.to_s)
        errors.add(:name, 'must consist of alphanumeric characters and hyphens')
      end
    end

    def mutually_exclusive_fields
      if requested?(:internal) && internal == true && requested?(:relationships)
        errors.add(:base, 'Cannot associate an internal domain with an organization')
      end
      if requested?(:internal) && internal == true && requested?(:router_group)
        errors.add(:base, 'Internal domains cannot be associated to a router group.')
      end
      if requested?(:relationships) && requested?(:router_group)
        errors.add(:base, 'Domains scoped to an organization cannot be associated to a router group.')
      end
    end

    def router_group_validation
      return if router_group.nil?
      return errors.add(:router_group, 'must be an object') unless router_group.is_a?(Hash)

      extra_keys = router_group.keys - [:guid]
      if extra_keys.any?
        errors.add(:router_group, "Unknown field(s): '#{extra_keys.join("', '")}'")
      end

      errors.add(:router_group, 'guid must be a string') unless router_group_guid.is_a?(String)
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
