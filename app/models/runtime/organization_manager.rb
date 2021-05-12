module VCAP::CloudController
  class OrganizationManager < Sequel::Model(:organizations_managers)
    include OrganizationRoleMixin

    def type
      @type ||= RoleTypes::ORGANIZATION_MANAGER
    end
  end
end
