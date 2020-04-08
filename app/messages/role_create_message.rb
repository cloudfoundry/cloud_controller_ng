require 'messages/metadata_base_message'
require 'models/helpers/role_types'

module VCAP::CloudController
  class RoleCreateMessage < BaseMessage
    register_allowed_keys [:type, :relationships]

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator

    validates :type,
      inclusion: {
        in: VCAP::CloudController::RoleTypes::ALL_ROLES,
        message: "must be one of the allowed types #{VCAP::CloudController::RoleTypes::ALL_ROLES}"
      }

    delegate :space_guid, :user_guid, :organization_guid, :username, :user_origin, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(type, relationships&.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      attr_reader :type
      register_allowed_keys [:space, :user, :organization]

      def initialize(role_type, params)
        @type = role_type
        super(params)
      end

      def has_user_validation_errors?
        errors[:username].any? || errors[:user_origin].any? || errors[:user].any?
      end

      def has_org_or_space_validation_errors?
        errors[:base].any? || errors[:space].any? || errors[:organization].any?
      end

      validates_with NoAdditionalKeysValidator

      validates :user, presence: true
      validate :user_input_combinations
      validate :organization_or_space_input_combinations
      validates :space, presence: true, allow_nil: false, to_one_relationship: true, if: -> { !has_org_or_space_validation_errors? && organization.nil? }
      validates :organization, presence: true, to_one_relationship: true, if: -> { !has_org_or_space_validation_errors? && space.nil? }

      validates :user, to_one_relationship: true, if: -> { !has_user_validation_errors? && has_user_guid? }

      validates :username, string: true, if: -> { !has_user_validation_errors? && has_username? }
      validates :user_origin, string: true, allow_nil: true, if: -> { !has_user_validation_errors? && has_user_origin? }

      def username
        HashUtils.dig(user, :data, :username)
      end

      def user_origin
        HashUtils.dig(user, :data, :origin)
      end

      def user_guid
        HashUtils.dig(user,  :data, :guid)
      end

      def space_guid
        HashUtils.dig(space, :data, :guid)
      end

      def organization_guid
        HashUtils.dig(organization, :data, :guid)
      end

      private

      [:user, :space, :organization].each do |symbol|
        define_method "#{symbol}_data" do
          HashUtils.dig(self.send(symbol), :data)
        end
      end

      def has_user_guid?
        return false unless user_data && user_data.is_a?(Hash)

        user_data.key?(:guid)
      end

      def has_username?
        return false unless user_data && user_data.is_a?(Hash)

        user_data.key?(:username)
      end

      def has_user_origin?
        return false unless user_data && user_data.is_a?(Hash)

        user_data.key?(:origin)
      end

      def user_input_combinations
        if has_user_guid? && has_username?
          errors.add(:username, 'cannot be specified when identifying user by guid')
        end

        if has_user_guid? && has_user_origin?
          errors.add(:user_origin, 'cannot be specified when identifying user by guid')
        end

        if !has_username? && has_user_origin?
          errors.add(:user_origin, 'cannot be specified without specifying the username')
        end

        if !has_username? && !has_user_guid?
          errors.add(:user, 'must have a username or guid specified')
        end
      end

      def organization_or_space_input_combinations
        if space_data.nil? && organization_data.nil?
          errors.add(:base, 'must specify either a space or an organization.')
        end

        if space_data && VCAP::CloudController::RoleTypes::ORGANIZATION_ROLES.include?(type)
          errors.add(:space, "cannot be provided with the organization role type: '#{type}'.")
        end

        if organization_data && VCAP::CloudController::RoleTypes::SPACE_ROLES.include?(type)
          errors.add(:organization, "cannot be provided with the space role type: '#{type}'.")
        end

        if space_data && organization_data
          errors.add(:base, 'cannot specify both an organization and a space.')
        end
      end
    end
  end
end
