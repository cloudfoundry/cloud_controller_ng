module VCAP::CloudController
  class OrganizationCreate
    class Error < ::StandardError
    end

    def initialize(perm_client:)
      @perm_client = perm_client
    end

    def create(message)
      org = nil
      Organization.db.transaction do
        org = VCAP::CloudController::Organization.create(name: message.name)

        MetadataUpdate.update(org, message)
      end

      VCAP::CloudController::Roles::ORG_ROLE_NAMES.each do |role|
        perm_client.create_org_role(role: role, org_id: org.guid)
      end

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
