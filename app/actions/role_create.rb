require 'models/helpers/role_types'
require 'repositories/user_event_repository'

module VCAP::CloudController
  class RoleCreate
    class Error < StandardError
    end

    def initialize(message, user_audit_info)
      @message = message
      @user_audit_info = user_audit_info
    end

    def create_space_role(type:, user:, space:)
      error!("Users cannot be assigned roles in a space if they do not have a role in that space's organization.") unless space.in_organization?(user)

      UsernamePopulator.new(uaa_username_lookup_client).transform(user)

      case type
      when RoleTypes::SPACE_AUDITOR
        create_space_auditor(user, space, type)
      when RoleTypes::SPACE_DEVELOPER
        create_space_developer(user, space, type)
      when RoleTypes::SPACE_MANAGER
        create_space_manager(user, space, type)
      when RoleTypes::SPACE_SUPPORTER
        create_space_supporter(user, space, type)
      else
        error!("Role type '#{type}' is invalid.")
      end
    rescue Sequel::ValidationFailed => e
      space_validation_error!(type, e, user, space)
    end

    def create_organization_role(type:, user:, organization:)
      UsernamePopulator.new(uaa_username_lookup_client).transform(user)

      case type
      when RoleTypes::ORGANIZATION_USER
        create_organization_user(user, organization, type)
      when RoleTypes::ORGANIZATION_AUDITOR
        create_organization_auditor(user, organization, type)
      when RoleTypes::ORGANIZATION_MANAGER
        create_organization_manager(user, organization, type)
      when RoleTypes::ORGANIZATION_BILLING_MANAGER
        create_organization_billing_manager(user, organization, type)
      else
        error!("Role type '#{type}' is invalid.")
      end
    rescue Sequel::ValidationFailed => e
      organization_validation_error!(type, e, user, organization)
    end

    private

    def event_repo
      @event_repo ||= Repositories::UserEventRepository.new
    end

    def create_space_auditor(user, space, role_type)
      event_repo.record_space_role_add(space, user, role_type, @user_audit_info, @message.audit_hash)
      SpaceAuditor.create(user_id: user.id, space_id: space.id)
    end

    def create_space_developer(user, space, role_type)
      event_repo.record_space_role_add(space, user, role_type, @user_audit_info, @message.audit_hash)
      SpaceDeveloper.create(user_id: user.id, space_id: space.id)
    end

    def create_space_manager(user, space, role_type)
      event_repo.record_space_role_add(space, user, role_type, @user_audit_info, @message.audit_hash)
      SpaceManager.create(user_id: user.id, space_id: space.id)
    end

    def create_space_supporter(user, space, role_type)
      event_repo.record_space_role_add(space, user, role_type, @user_audit_info, @message.audit_hash)
      SpaceSupporter.create(user_id: user.id, space_id: space.id)
    end

    def create_organization_user(user, organization, role_type)
      event_repo.record_organization_role_add(organization, user, role_type, @user_audit_info, @message.audit_hash)
      OrganizationUser.create(user_id: user.id, organization_id: organization.id)
    end

    def create_organization_auditor(user, organization, role_type)
      event_repo.record_organization_role_add(organization, user, role_type, @user_audit_info, @message.audit_hash)
      OrganizationAuditor.create(user_id: user.id, organization_id: organization.id)
    end

    def create_organization_manager(user, organization, role_type)
      event_repo.record_organization_role_add(organization, user, role_type, @user_audit_info, @message.audit_hash)
      OrganizationManager.create(user_id: user.id, organization_id: organization.id)
    end

    def create_organization_billing_manager(user, organization, role_type)
      event_repo.record_organization_role_add(organization, user, role_type, @user_audit_info, @message.audit_hash)
      OrganizationBillingManager.create(user_id: user.id, organization_id: organization.id)
    end

    def space_validation_error!(type, error, user, space)
      error!("User '#{user.presentation_name}' already has '#{type}' role in space '#{space.name}'.") if error.errors.on(%i[space_id user_id])&.any? { |e| [:unique].include?(e) }

      error!(error.message)
    end

    def organization_validation_error!(type, error, user, organization)
      error!("User '#{user.presentation_name}' already has '#{type}' role in organization '#{organization.name}'.") if error.errors.on(%i[organization_id user_id])&.any? do |e|
                                                                                                                         [:unique].include?(e)
                                                                                                                       end

      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end

    def uaa_username_lookup_client
      CloudController::DependencyLocator.instance.uaa_username_lookup_client
    end
  end
end
