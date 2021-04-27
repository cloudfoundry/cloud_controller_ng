module VCAP::CloudController
  class OrganizationBillingManager < Sequel::Model(:organizations_billing_managers)
    include OrganizationRoleMixin

    def type
      @type ||= RoleTypes::ORGANIZATION_BILLING_MANAGER
    end
  end
end
