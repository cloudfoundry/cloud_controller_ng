module VCAP::CloudController
  class OrganizationBillingManager < Sequel::Model(:organizations_billing_managers)
    many_to_one :user
    many_to_one :organization

    def validate
      validates_unique [:organization_id, :user_id]
      validates_presence :organization_id
      validates_presence :user_id
    end

    def type
      @type ||= RoleTypes::ORGANIZATION_BILLING_MANAGER
    end
  end
end
