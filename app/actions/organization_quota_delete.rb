require 'repositories/organization_quota_event_repository'

module VCAP::CloudController
  class OrganizationQuotaDeleteAction
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(organization_quotas)
      organization_quotas.each do |org_quota|
        QuotaDefinition.db.transaction do
          Repositories::OrganizationQuotaEventRepository.new.record_organization_quota_delete(org_quota, @user_audit_info)
          org_quota.destroy
        end
      end
      []
    end
  end
end
