require 'messages/metadata_base_message'
require 'models/helpers/role_types'

module VCAP::CloudController
  class RoleCreateMessage < BaseMessage
    register_allowed_keys [:type, :relationships]

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator
    validates_with SpaceOrOrgPresentValidator
    validates_with UserRoleCreationValidator

    validates :type, inclusion: {
      in: VCAP::CloudController::RoleTypes::ALL_ROLES,
      message: "must be one of the allowed types #{VCAP::CloudController::RoleTypes::ALL_ROLES}"
    }

    delegate :space_guid, :user_guid, :organization_guid, :user_name, :user_origin, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:space, :user, :organization]

      validates_with NoAdditionalKeysValidator

      validates :space, presence: true, allow_nil: false, to_one_relationship: true, if: -> { organization.nil? }
      validates :organization, presence: true, to_one_relationship: true, if: -> { space.nil? }
      validates :user, presence: true
      validates :user, to_one_relationship: true, if: -> { user_name.nil? }

      validates :user_name, string: true, if: -> { user_guid.nil? }
      validates :user_origin, string: true, allow_nil: true, if: -> { user_guid.nil? }

      def user_name
        HashUtils.dig(user, :data, :name)
      end

      def user_origin
        HashUtils.dig(user, :data, :origin)
      end

      def space_guid
        HashUtils.dig(space, :data, :guid)
      end

      def user_guid
        HashUtils.dig(user,  :data, :guid)
      end

      def organization_guid
        HashUtils.dig(organization, :data, :guid)
      end
    end
  end
end
