require 'repositories/service_instance_share_event_repository'
require 'actions/mixins/service_instance_create'

module VCAP::CloudController
  class ServiceInstanceCreateUserProvided
    include ServiceInstanceCreateMixin

    class InvalidUserProvidedServiceInstance < ::StandardError
    end

    def initialize(service_event_repository)
      @service_event_repository = service_event_repository
    end

    def create(message)
      instance = nil
      attributes = {
        name: message.name,
        space_guid: message.space_guid,
        tags: message.tags,
        credentials: message.credentials,
        syslog_drain_url: message.syslog_drain_url,
        route_service_url: message.route_service_url,
      }
      last_operation = {
        type: 'create',
        state: 'succeeded',
        description: 'Operation succeeded',
      }

      UserProvidedServiceInstance.db.transaction do
        instance = UserProvidedServiceInstance.new
        instance.save_with_new_operation(attributes, last_operation)
        MetadataUpdate.update(instance, message)
        service_event_repository.record_user_provided_service_instance_event(:create, instance, message.audit_hash)
      end

      instance
    rescue Sequel::ValidationFailed => e
      validation_error!(
        e,
        name: message.name,
        validation_error_handler: ValidationErrorHandler.new
      )
    end

    private

    class ValidationErrorHandler
      def error!(message)
        raise InvalidUserProvidedServiceInstance.new(message)
      end
    end

    attr_reader :service_event_repository
  end
end
