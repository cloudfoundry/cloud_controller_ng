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

      uaa_client = CloudController::DependencyLocator.instance.uaa_client
      UsernamePopulator.new(uaa_client).transform(user)

      case type
      when RoleTypes::SPACE_AUDITOR
        create_space_auditor(user, space)
      when RoleTypes::SPACE_DEVELOPER
        create_space_developer(user, space)
      when RoleTypes::SPACE_MANAGER
        create_space_manager(user, space)
      when RoleTypes::SPACE_SUPPORTER
        create_space_supporter(user, space)
      else
        error!("Role type '#{type}' is invalid.")
      end
    rescue Sequel::ValidationFailed => e
      space_validation_error!(type, e, user, space)
    end

    def create_organization_role(type:, user:, organization:)
      uaa_client = CloudController::DependencyLocator.instance.uaa_client
      UsernamePopulator.new(uaa_client).transform(user)

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

    def event_repo
      @event_repo ||= Repositories::UserEventRepository.new
    end

    def create_space_auditor(user, space)
      record_space_event(space, user, 'auditor')
      SpaceAuditor.create(user_id: user.id, space_id: space.id)
    end

    def create_space_developer(user, space)
      record_space_event(space, user, 'developer')
      SpaceDeveloper.create(user_id: user.id, space_id: space.id)
    end

    def create_space_manager(user, space)
      record_space_event(space, user, 'manager')
      SpaceManager.create(user_id: user.id, space_id: space.id)
    end

    def create_space_supporter(user, space)
      record_space_event(space, user, 'supporter')
      SpaceSupporter.create(user_id: user.id, space_id: space.id)
    end

    def create_organization_user(user, organization)
      record_organization_event(organization, user, 'user')
      OrganizationUser.create(user_id: user.id, organization_id: organization.id)
    end

    def create_organization_auditor(user, organization)
      record_organization_event(organization, user, 'auditor')
      OrganizationAuditor.create(user_id: user.id, organization_id: organization.id)
    end

    def create_organization_manager(user, organization)
      record_organization_event(organization, user, 'manager')
      OrganizationManager.create(user_id: user.id, organization_id: organization.id)
    end

    def create_organization_billing_manager(user, organization)
      record_organization_event(organization, user, 'billing_manager')
      OrganizationBillingManager.create(user_id: user.id, organization_id: organization.id)
    end

    def record_space_event(space, user, short_event_type)
      event_repo.record_space_role_add(space, user, short_event_type, @user_audit_info, @message.audit_hash)
    end

    def record_organization_event(org, user, short_event_type)
      event_repo.record_organization_role_add(org, user, short_event_type, @user_audit_info, @message.audit_hash)
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
