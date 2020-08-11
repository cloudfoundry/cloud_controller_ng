require 'messages/service_instance_message'

module VCAP::CloudController
  class ServiceInstanceUpdateUserProvidedMessage < ServiceInstanceMessage
    register_allowed_keys [
      :name,
      :tags,
      :credentials,
      :syslog_drain_url,
      :route_service_url,
    ]

    validates_with NoAdditionalKeysValidator

    validates :name, string: true, allow_blank: true
    validates :tags, array: true, allow_blank: true
    validates :credentials, hash: true, allow_blank: true
    validates :syslog_drain_url, uri: true, allow_blank: true
    validates :route_service_url, uri: true, allow_blank: true

    validate :tags_must_be_strings
    validate :route_service_url_must_be_https

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
  end
end
