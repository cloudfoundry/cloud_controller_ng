require 'messages/service_instance_create_message'
require 'presenters/helpers/censorship'

module VCAP::CloudController
  class ServiceInstanceCreateUserProvidedMessage < ServiceInstanceCreateMessage
    register_allowed_keys [
      :credentials,
      :syslog_drain_url,
      :route_service_url,
    ]

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator

    validates :type, allow_blank: false, inclusion: {
      in: %w(user-provided),
      message: "must be 'user-provided'"
    }
    validates :credentials, hash: true, allow_blank: true
    validates :syslog_drain_url, uri: true, allow_blank: true
    validates :route_service_url, uri: true, allow_blank: true
    validate :route_service_url_must_be_https

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    private

    def route_service_url_must_be_https
      if route_service_url.present? && route_service_url.is_a?(String) && !route_service_url.starts_with?('https:')
        errors.add(:route_service_url, 'must be https')
      end
    end

    class Relationships < ServiceInstanceCreateMessage::Relationships
      validates_with NoAdditionalKeysValidator
    end
  end
end
