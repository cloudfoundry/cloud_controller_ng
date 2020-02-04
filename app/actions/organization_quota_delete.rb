module VCAP::CloudController
  class OrganizationQuotaDeleteAction
    def delete(organization_quotas)
      organization_quotas.each do |org_quota|
        QuotaDefinition.db.transaction do
          org_quota.destroy
        end
      end
      []
    end
  end
end
