module VCAP::CloudController
  module Repositories
    module Runtime
      class DomainEventRepository
        def record_domain_delete_request(domain, actor, actor_name)
          Event.create(
            type: 'audit.domain.delete-request',
            actee: domain.guid,
            actee_type: 'domain',
            actee_name: domain.name,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            organization_guid: organization_guid(domain)
          )
        end

        private

        def organization_guid(domain)
          if domain.owning_organization.nil?
            ''
          else
            domain.owning_organization.guid
          end
        end
      end
    end
  end
end
