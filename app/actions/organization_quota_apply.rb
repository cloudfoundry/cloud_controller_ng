module VCAP::CloudController
  class OrganizationQuotaApply
    class Error < ::StandardError
    end

    def apply(org_quota, message)
      orgs = valid_orgs(message.organization_guids)

      if org_quota.log_rate_limit != QuotaDefinition::UNLIMITED
        affected_processes = Organization.where(Sequel[:organizations][:id] => orgs.map(&:id)).
                             join(:spaces, organization_id: :id).
                             join(:apps, space_guid: :guid).
                             join(:processes, app_guid: :guid)

        unless affected_processes.where(log_rate_limit: ProcessModel::UNLIMITED_LOG_RATE).empty?
          error!('Current usage exceeds new quota values. The org(s) being assigned this quota contain apps running with an unlimited log rate limit.')
        end
      end

      QuotaDefinition.db.transaction do
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
      error!("Organizations with guids #{invalid_org_guids} do not exist")
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
