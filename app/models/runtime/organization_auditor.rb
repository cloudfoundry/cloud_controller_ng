module VCAP::CloudController
  class OrganizationAuditor < Sequel::Model(:organizations_auditors)
    include OrganizationRoleMixin

    def type
      @type ||= RoleTypes::ORGANIZATION_AUDITOR
    end
  end
end
