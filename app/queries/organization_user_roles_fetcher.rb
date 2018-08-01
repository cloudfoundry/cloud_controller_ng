module VCAP::CloudController
  class OrganizationUserRolesFetcher
    def self.fetch(org, user_guid: nil)
      new(user_guid: user_guid).fetch(org)
    end

    attr_reader :user_guid

    def initialize(user_guid: nil)
      @user_guid = user_guid
    end

    def fetch(org)
      filter_if_user_guid(org.users_dataset).
        union(filter_if_user_guid(org.managers_dataset)).
        union(filter_if_user_guid(org.auditors_dataset)).
        union(filter_if_user_guid(org.billing_managers_dataset)).
        eager(:organizations, :managed_organizations, :billing_managed_organizations, :audited_organizations)
    end

    def filter_if_user_guid(dataset)
      return dataset unless user_guid
      dataset.filter(guid: user_guid)
    end
  end
end
