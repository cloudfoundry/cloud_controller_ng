require 'role_create'

module VCAP::CloudController
  class OrganizationCreate
    class Error < ::StandardError
    end

    def initialize(perm_client:, user_audit_info:)
      @perm_client = perm_client
      @user_audit_info = user_audit_info
    end

    def create(message, user)
      org = nil
      Organization.db.transaction do
        org = VCAP::CloudController::Organization.create(
          name: message.name,
          status: message.suspended ? Organization::SUSPENDED : Organization::ACTIVE,
        )

        MetadataUpdate.update(org, message)
      end

      VCAP::CloudController::RoleTypes::ORGANIZATION_ROLES.each do |role|
        VCAP::CloudController::RoleCreate.new(message, @user_audit_info).create_organization_role(type: role,
                                                                   user: user,
                                                                   organization: org)
      end

      Repositories::OrganizationEventRepository.new.record_organization_create(org, @user_audit_info, message.audit_hash)
      org
    rescue Sequel::ValidationFailed => e
      validation_error!(e, message)
    end

    private

    attr_reader :perm_client

    def validation_error!(error, message)
      if error.errors.on(:name)&.include?(:unique)
        error!("Organization '#{message.name}' already exists.")
      end
      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
