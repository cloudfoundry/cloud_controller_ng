require 'repositories/deployment_event_repository'

module VCAP::CloudController
  class DomainDeleteSharedOrg
    class OrgError < ::StandardError
    end

    class RouteError < ::StandardError
    end

    def self.delete(domain:, shared_organization:)
      Domain.db.transaction do
        raise OrgError.new if org_error(domain, shared_organization)

        raise RouteError.new if routes?(domain, shared_organization.guid)

        domain.remove_shared_organization(shared_organization)
      end
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
