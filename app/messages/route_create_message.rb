require 'messages/metadata_base_message'
require 'messages/route_options_message'

module VCAP::CloudController
  class RouteCreateMessage < MetadataBaseMessage
    MAXIMUM_DOMAIN_LABEL_LENGTH = 63
    MAXIMUM_PATH_LENGTH = 128

    register_allowed_keys %i[
      host
      path
      port
      relationships
      options
    ]

    def self.options_requested?
      @options_requested ||= proc { |a| a.requested?(:options) }
    end

    validates :host,
              allow_nil: true,
              string: true,
              length: {
                maximum: MAXIMUM_DOMAIN_LABEL_LENGTH
              },
              format: {
                with: /\A([\w\-]+|\*)?\z/,
                message: 'must be either "*" or contain only alphanumeric characters, "_", or "-"'
              }

    validates :path,
              allow_nil: true,
              string: true,
              length: {
                maximum: MAXIMUM_PATH_LENGTH
              },
              format: {
                with: %r{\A(/.*|)\z},
                message: 'must begin with /'
              }

    validates :path,
              allow_nil: true,
              format: {
                without: /\?/,
                message: 'cannot contain ?'
              }

    validates :path,
              allow_nil: true,
              format: {
                without: %r{\A/\z},
                message: 'cannot be exactly /'
              }

    validates :port,
              allow_nil: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 65_535 }

    validates :relationships, presence: true

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator
    validates_with OptionsValidator, if: options_requested?

    delegate :space_guid, to: :relationships_message
    delegate :domain_guid, to: :relationships_message

    def relationships_message
      # need the & instead of doing if requested(rel..) because we can't delegate if rl_msg nil
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    def options_message
      @options_message ||= RouteOptionsMessage.new(options&.deep_symbolize_keys)
    end

    def wildcard?
      host == '*'
    end

    class Relationships < BaseMessage
      register_allowed_keys %i[space domain]

      validates_with NoAdditionalKeysValidator
      validates :space, presence: true, to_one_relationship: true
      validates :domain, presence: true, to_one_relationship: true

      def space_guid
        HashUtils.dig(space, :data, :guid)
      end

      def domain_guid
        HashUtils.dig(domain, :data, :guid)
      end
    end
  end
end
