require 'repositories/deployment_event_repository'

module VCAP::CloudController
  class DomainCreate
    class Error < StandardError; end

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
    rescue Sequel::ValidationFailed => e
      validation_error!(message.name, e)
    end

    private

    def validation_error!(name, error)
      if error.errors.on(:name)&.any? { |e| [:unique, :overlapping_domain, :route_conflict].include?(e) }
        error!("The domain name \"#{name}\" is already reserved by another domain or route.")
      end
      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
