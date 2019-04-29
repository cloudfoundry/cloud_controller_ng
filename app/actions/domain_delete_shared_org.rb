require 'repositories/deployment_event_repository'

module VCAP::CloudController
  class DomainDeleteSharedOrg
    class Error < ::StandardError
    end

    def self.delete(domain:, shared_organization:)
      Domain.db.transaction do
        if org_error(domain, shared_organization)
          error!("Unable to unshare domain from organization with guid '#{shared_organization.guid}'. Ensure the domain is shared to this organization.")
        end
        error!('This domain has associated routes in this organization. Delete the routes before unsharing.') if routes?(domain, shared_organization.guid)
        domain.remove_shared_organization(shared_organization)
      end
    end

    def self.error!(message)
      raise Error.new(message)
    end

    def self.org_error(domain, shared_organization)
      !(domain.shared_organizations.include?(shared_organization) && domain.owning_organization) || domain.owning_organization.guid == shared_organization.guid
    end

    def self.routes?(domain, org_guid)
      domain.routes.any? do |route|
        route.space.organization_guid == org_guid
      end
    end
  end
end
