module VCAP::CloudController
  class OrganizationUserRolesFetcher
    def fetch(org)
      user_dataset = org.users_dataset.
      union(org.managers_dataset).
      union(org.auditors_dataset).
      union(org.billing_managers_dataset).
      eager(:organizations, :managed_organizations, :billing_managed_organizations, :audited_organizations)

      user_dataset
    end
  end
end
