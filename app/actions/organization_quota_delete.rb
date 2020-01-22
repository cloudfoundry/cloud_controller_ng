module VCAP::CloudController
  class OrganizationQuotaDeleteAction
    def delete(organization_quota)
      QuotaDefinition.db.transaction do
        organization_quota.destroy
      end
    end
  end
end
