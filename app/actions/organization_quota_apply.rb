module VCAP::CloudController
  class OrganizationQuotaApply
    class Error < ::StandardError
    end

    def apply(org_quota, message)
      QuotaDefinition.db.transaction do
        orgs = valid_orgs(message.organization_guids)
        orgs.each { |org| org_quota.add_organization(org) }
      end
    rescue Sequel::ValidationFailed => e
      error!(e.message)
    end

    private

    def valid_orgs(org_guids)
      orgs = Organization.where(guid: org_guids).all
      return orgs if orgs.length == org_guids.length

      invalid_org_guids = org_guids - orgs.map(&:guid)
      error!("Organizations with guids #{invalid_org_guids} do not exist, or you do not have access to them.")
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
