module VCAP::CloudController
  class OrganizationQuotaDeleteAction
    def delete(organization_quota)
      organization_quota.each do |org_quota|
        QuotaDefinition.db.transaction do
          org_quota.destroy
        end
      end
      []
    end
  end
end
