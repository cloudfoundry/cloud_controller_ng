require 'repositories/deployment_event_repository'

module VCAP::CloudController
  class DomainCreate
    class << self
      def create(message:)
        domain = SharedDomain.new(
          name: message.name,
          internal: message.internal,
        )

        SharedDomain.db.transaction do
          domain.save
        end

        domain
      end
    end
  end
end
