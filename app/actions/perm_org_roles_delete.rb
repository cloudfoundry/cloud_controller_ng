module VCAP::CloudController
  class PermOrgRolesDelete
    def initialize(client)
      @client = client
    end

    def delete(org)
      @client = client.rehydrate
      VCAP::CloudController::Roles::ORG_ROLE_NAMES.each do |role|
        begin
          client.delete_org_role(role: role, org_id: org.guid)
        rescue
          return [CloudController::Errors::ApiError.new_from_details('OrganizationRolesDeletionFailed', org.name)]
        end
      end
      []
    end

    def timeout_error(org)
      CloudController::Errors::ApiError.new_from_details('OrganizationRolesDeletionTimeout', org.name)
    end

    private

    attr_reader :client
  end
end
