require 'messages/base_message'
require 'models/helpers/process_types'

module VCAP::CloudController
  class RouteMappingsCreateMessage < BaseMessage
    register_allowed_keys [:relationships, :weight]

    validates_with NoAdditionalKeysValidator
    validates :app, hash: true
    validates :app_guid, guid: true
    validates :route, hash: true
    validates :route_guid, guid: true
    validates :process, hash: true, allow_nil: true
    validates :process_type, string: true, allow_nil: true
    validates_inclusion_of :weight, in: 1..128, allow_nil: true, message: '%{value} must be an integer between 1 and 128'

    def app
      HashUtils.dig(relationships, :app)
    end

    def app_guid
      HashUtils.dig(app, :guid)
    end

    def process
      HashUtils.dig(relationships, :process)
    end

    def process_type
      HashUtils.dig(process, :type) || ProcessTypes::WEB
    end

    def route
      HashUtils.dig(relationships, :route)
    end

    def route_guid
      HashUtils.dig(route, :guid)
    end
  end
end
