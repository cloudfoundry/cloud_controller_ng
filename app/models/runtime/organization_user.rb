module VCAP::CloudController
  class OrganizationUser < Sequel::Model(:organizations_users)
    include OrganizationRoleMixin

    def type
      @type ||= RoleTypes::ORGANIZATION_USER
    end
  end
end
