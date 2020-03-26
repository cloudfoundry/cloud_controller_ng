require 'messages/metadata_base_message'
require 'presenters/helpers/censorship'
require 'utils/hash_utils'

module VCAP::CloudController
  class ServiceInstanceCreateMessage < MetadataBaseMessage
    register_allowed_keys [
      :type,
      :relationships,
      :name,
      :credentials,
      :syslog_drain_url,
      :route_service_url,
      :tags,
    ]

    validates_with RelationshipValidator
    validates_with NoAdditionalKeysValidator

    validates :type, allow_blank: false, inclusion: {
        in: %w(user-provided),
        message: "must be one of 'managed', 'user-provided'"
      }
    validates :name, string: true, presence: true
    validates :credentials, hash: true, allow_blank: true
    validates :syslog_drain_url, uri: true, allow_blank: true
    validates :route_service_url, uri: true, allow_blank: true
    validate :route_service_url_must_be_https
    validates :tags, array: true, allow_blank: true
    validate :tags_must_be_strings

    delegate :space_guid, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    def audit_hash
      super.tap { |h| h['credentials'] = VCAP::CloudController::Presenters::Censorship::PRIVATE_DATA_HIDDEN }
    end

    private

    def route_service_url_must_be_https
      if route_service_url.present? && route_service_url.is_a?(String) && !route_service_url.starts_with?('https:')
        errors.add(:route_service_url, 'must be https')
      end
    end

    def tags_must_be_strings
      if tags.present? && tags.is_a?(Array) && tags.any? { |i| !i.is_a?(String) }
        errors.add(:tags, 'must be a list of strings')
      end
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
