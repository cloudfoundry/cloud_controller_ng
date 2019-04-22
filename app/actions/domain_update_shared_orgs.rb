require 'repositories/deployment_event_repository'

module VCAP::CloudController
  class DomainUpdateSharedOrgs
    def self.update(domain:, shared_organizations: [])
      new_shared_orgs = shared_organizations - domain.shared_organizations

      Domain.db.transaction do
        new_shared_orgs.each do |shared_org|
          domain.add_shared_organization(shared_org)
        end
      end

      domain
    end
  end
end
