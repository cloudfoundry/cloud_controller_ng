require 'messages/base_message'
require 'messages/validators'
require 'messages/empty_lifecycle_data_message'

module VCAP::CloudController
  class DropletCopyMessage < BaseMessage
    register_allowed_keys [:relationships]

    validates_with NoAdditionalKeysValidator
    validates :app, hash: true
    validates :app_guid, guid: true

    def app
      HashUtils.dig(relationships, :app)
    end

    def app_guid
      HashUtils.dig(app, :data, :guid)
    end
  end
end
