require 'messages/metadata_base_message'

module VCAP::CloudController
  class RoleCreateMessage < BaseMessage
    register_allowed_keys [:type, :relationships]

    validates_with NoAdditionalKeysValidator
    validates :user_guid, guid: true, presence: true, string: true
    validates :space_guid, guid: true, presence: true, string: true

    def user_guid
      HashUtils.dig(relationships, :user, :data, :guid)
    end

    def space_guid
      HashUtils.dig(relationships, :space, :data, :guid)
    end
  end
end
