require 'repositories/deployment_event_repository'

module VCAP::CloudController
  class DomainDeleteSharedOrg
    class Error < ::StandardError
    end

    def self.delete(domain:, shared_organization:)
      Domain.db.transaction do
        error! unless domain.owning_organization
        error! if domain.owning_organization.guid == shared_organization.guid
        error! unless domain.shared_organizations.include?(shared_organization)

        domain.remove_shared_organization(shared_organization)
      end
    end

    def self.error!
      raise Error.new
    end
  end
end
