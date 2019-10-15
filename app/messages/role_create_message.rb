require 'messages/metadata_base_message'
require 'models/helpers/role_types'

module VCAP::CloudController
  class RoleCreateMessage < BaseMessage
    register_allowed_keys [:type, :relationships]

    validates_with NoAdditionalKeysValidator
    validates_with SpaceOrOrgPresentValidator
    validates :user_guid, guid: true, presence: true
    validates :space_guid, guid: true, allow_nil: true
    validates :organization_guid, guid: true, allow_nil: true
    validates :type, inclusion: {
      in: VCAP::CloudController::RoleTypes::ALL_ROLES,
      message: "must be one of the allowed types #{VCAP::CloudController::RoleTypes::ALL_ROLES}"
    }

    def user_guid
      HashUtils.dig(relationships, :user, :data, :guid)
    end

    def space_guid
      HashUtils.dig(relationships, :space, :data, :guid)
    end

    def organization_guid
      HashUtils.dig(relationships, :organization, :data, :guid)
    end
  end
end
