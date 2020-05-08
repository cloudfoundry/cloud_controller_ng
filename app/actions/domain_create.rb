require 'repositories/deployment_event_repository'

module VCAP::CloudController
  class DomainCreate
    class Error < StandardError
    end

    INTERNAL_DEFAULT = false

    def create(message:, shared_organizations: [])
      domain = if message.requested?(:relationships)
                 PrivateDomain.new(
                   name: message.name,
                   owning_organization_guid: message.organization_guid
                 )
               else
                 SharedDomain.new(
                   name: message.name,
                   internal: message.internal.nil? ? INTERNAL_DEFAULT : message.internal,
                 )
               end

      domain.router_group_guid = message.router_group_guid

      Domain.db.transaction do
        domain.save

        MetadataUpdate.update(domain, message)

        shared_organizations.each do |shared_org|
          domain.add_shared_organization(shared_org)
        end
      end

      domain
    rescue Sequel::ValidationFailed => e
      validation_error!(message, e)
    end

    private

    def validation_error!(message, error)
      if error.errors.on(:name)&.any? { |e| [:unique].include?(e) }
        error!("The domain name \"#{message.name}\" is already in use")
      end

      if error.errors.on(:name)&.any? { |e| [:reserved].include?(e) }
        error!("The \"#{message.name}\" domain is reserved and cannot be used for org-scoped domains.")
      end

      if error.errors.on(:organization)&.any? { |e| [:total_private_domains_exceeded].include?(e) }
        error!("The number of private domains exceeds the quota for organization \"#{Organization.find(guid: message.organization_guid).name}\"")
      end

      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
