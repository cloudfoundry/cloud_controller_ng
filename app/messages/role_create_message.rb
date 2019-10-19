require 'messages/metadata_base_message'
require 'models/helpers/role_types'

module VCAP::CloudController
  class RoleCreateMessage < BaseMessage
    register_allowed_keys [:type, :relationships]

    validates_with NoAdditionalKeysValidator
    validates_with SpaceOrOrgPresentValidator
    validates_with UserRoleCreationValidator
    validates :user_guid, guid: true, if: -> { user_name.nil? }
    validates :user_name, string: true, if: -> { user_guid.nil? }
    validates :user_origin, string: true, allow_nil: true, if: -> { user_guid.nil? }
    validates :space_guid, guid: true, allow_nil: true
    validates :organization_guid, guid: true, allow_nil: true
    validates :type, inclusion: {
      in: VCAP::CloudController::RoleTypes::ALL_ROLES,
      message: "must be one of the allowed types #{VCAP::CloudController::RoleTypes::ALL_ROLES}"
    }

    def user_guid
      HashUtils.dig(relationships, :user, :data, :guid)
    end

    def user_name
      HashUtils.dig(relationships, :user, :data, :name)
    end

    def user_origin
      HashUtils.dig(relationships, :user, :data, :origin)
    end

    def space_guid
      HashUtils.dig(relationships, :space, :data, :guid)
    end

    def organization_guid
      HashUtils.dig(relationships, :organization, :data, :guid)
    end
  end
end
