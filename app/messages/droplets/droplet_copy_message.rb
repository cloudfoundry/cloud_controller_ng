require 'messages/base_message'
require 'messages/validators'
require 'messages/lifecycles/docker_lifecycle_data_message'

module VCAP::CloudController
  class DropletCopyMessage < BaseMessage
    ALLOWED_KEYS = [:relationships].freeze

    attr_accessor(*ALLOWED_KEYS)
    validates_with NoAdditionalKeysValidator
    validates :app, hash: true
    validates :app_guid, guid: true

    def self.create_from_http_request(body)
      DropletCopyMessage.new(body.symbolize_keys)
    end

    def app
      HashUtils.dig(relationships, :app) || HashUtils.dig(relationships, 'app')
    end

    def app_guid
      HashUtils.dig(app, :guid) || HashUtils.dig(app, 'guid')
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
