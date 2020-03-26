require 'repositories/service_instance_share_event_repository'

module VCAP::CloudController
  class ServiceInstanceCreateUserProvided
    class InvalidUserProvidedServiceInstance < ::StandardError
    end

    def initialize(service_event_repository)
      @service_event_repository = service_event_repository
    end

    def create(message)
      instance = nil
      UserProvidedServiceInstance.db.transaction do
        instance = UserProvidedServiceInstance.create({
          name: message.name,
          space_guid: message.space_guid,
          tags: message.tags,
          credentials: message.credentials,
          syslog_drain_url: message.syslog_drain_url,
          route_service_url: message.route_service_url,
        })
        MetadataUpdate.update(instance, message)
        service_event_repository.record_user_provided_service_instance_event(:create, instance, message.audit_hash)
      end

      instance
    rescue Sequel::ValidationFailed => e
      raise InvalidUserProvidedServiceInstance.new(e.errors.full_messages.join(','))
    end

    private

    attr_reader :service_event_repository
  end
end
