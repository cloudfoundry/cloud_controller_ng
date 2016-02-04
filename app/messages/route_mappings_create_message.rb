require 'messages/base_message'

module VCAP::CloudController
  class RouteMappingsCreateMessage < BaseMessage
    ALLOWED_KEYS = [:relationships]

    attr_accessor(*ALLOWED_KEYS)
    validates_with NoAdditionalKeysValidator
    validates :route, hash: true
    validates :route_guid, guid: true
    validates :process, hash: true, allow_nil: true
    validates :process_type, string: true, allow_nil: true

    def self.create_from_http_request(body)
      RouteMappingsCreateMessage.new(body.symbolize_keys)
    end

    def process
      relationships.try(:[], 'process') || relationships.try(:[], :process)
    end

    def process_type
      if process.is_a?(Hash)
        process.try(:[], 'type') || process.try(:[], :type)
      end
    end

    def route
      relationships.try(:[], 'route') || relationships.try(:[], :route)
    end

    def route_guid
      if route.is_a?(Hash)
        route.try(:[], 'guid') || route.try(:[], :guid)
      end
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
