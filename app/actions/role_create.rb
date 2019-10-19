require 'models/helpers/role_types'

module VCAP::CloudController
  class RoleCreate
    class Error < StandardError
    end

    class << self
      def create_space_role(type:, user:, space:)
        error!("Users cannot be assigned roles in a space if they do not have a role in that space's organization.") unless space.in_organization?(user)

        case type
        when RoleTypes::SPACE_AUDITOR
          create_space_auditor(user, space)
        when RoleTypes::SPACE_DEVELOPER
          create_space_developer(user, space)
        when RoleTypes::SPACE_MANAGER
          create_space_manager(user, space)
        else
          error!("Role type '#{type}' is invalid.")
        end
      rescue Sequel::ValidationFailed => e
        space_validation_error!(type, e, user, space)
      end

      def create_organization_role(type:, user:, organization:)
        case type
        when RoleTypes::ORGANIZATION_USER
          create_organization_user(user, organization)
        when RoleTypes::ORGANIZATION_AUDITOR
          create_organization_auditor(user, organization)
        when RoleTypes::ORGANIZATION_MANAGER
          create_organization_manager(user, organization)
        when RoleTypes::ORGANIZATION_BILLING_MANAGER
          create_organization_billing_manager(user, organization)
        else
          error!("Role type '#{type}' is invalid.")
        end
      rescue Sequel::ValidationFailed => e
        organization_validation_error!(type, e, user, organization)
      end

      private

      def create_space_auditor(user, space)
        SpaceAuditor.create(user_id: user.id, space_id: space.id)
      end

      def create_space_developer(user, space)
        SpaceDeveloper.create(user_id: user.id, space_id: space.id)
      end

      def create_space_manager(user, space)
        SpaceManager.create(user_id: user.id, space_id: space.id)
      end

      def create_organization_user(user, organization)
        OrganizationUser.create(user_id: user.id, organization_id: organization.id)
      end

      def create_organization_auditor(user, organization)
        OrganizationAuditor.create(user_id: user.id, organization_id: organization.id)
      end

      def create_organization_manager(user, organization)
        OrganizationManager.create(user_id: user.id, organization_id: organization.id)
      end

      def create_organization_billing_manager(user, organization)
        OrganizationBillingManager.create(user_id: user.id, organization_id: organization.id)
      end

      def space_validation_error!(type, error, user, space)
        if error.errors.on([:space_id, :user_id])&.any? { |e| [:unique].include?(e) }
          error!("User '#{user.presentation_name}' already has '#{type}' role in space '#{space.name}'.")
        end

        error!(error.message)
      end

      def organization_validation_error!(type, error, user, organization)
        if error.errors.on([:organization_id, :user_id])&.any? { |e| [:unique].include?(e) }
          error!("User '#{user.presentation_name}' already has '#{type}' role in organization '#{organization.name}'.")
        end

        error!(error.message)
      end

      def error!(message)
        raise Error.new(message)
      end
    end
  end
end
