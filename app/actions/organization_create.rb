module VCAP::CloudController
  class OrganizationCreate
    class Error < ::StandardError
    end

    def initialize(perm_client:)
      @perm_client = perm_client
    end

    def create(message)
      org = VCAP::CloudController::Organization.create(name: message.name)
      VCAP::CloudController::Roles::ORG_ROLE_NAMES.each do |role|
        perm_client.create_org_role(role: role, org_id: org.guid)
      end

      LabelsUpdate.update(org, message.labels, OrgLabelModel) if message.requested?(:metadata)

      org
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end

    private

    attr_reader :perm_client

    def validation_error!(error)
      if error.errors.on(:name)&.include?(:unique)
        error!('Name must be unique')
      end
      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
