module VCAP::CloudController
  class DomainListFetcher
    def fetch(readable_org_guids)
      # for a possible optimization in lower-level Sequel,
      # see Organization#domains (which doesn't bring in shared private domains)
      # Also see Organization#private_domain_dataset might be combinable
      # with SharedDomain.dataset
      orgs = Organization.where(guid: readable_org_guids)
      domain_ids = orgs.map(&:private_domains).flatten.map(&:id).uniq
      Domain.where(id: domain_ids + SharedDomain.all.map(&:id))
    end
  end
end
