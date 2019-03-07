require 'repositories/deployment_event_repository'

module VCAP::CloudController
  class DomainCreate
    INTERNAL_DEFAULT = false

    def create(message:)
      domain = SharedDomain.new(
        name: message.name,
        internal: message.internal.nil? ? INTERNAL_DEFAULT : message.internal,
      )

      SharedDomain.db.transaction do
        domain.save
      end

      domain
    end
  end
end
