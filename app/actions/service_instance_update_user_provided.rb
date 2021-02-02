require 'actions/mixins/service_instance_create'

module VCAP::CloudController
  class ServiceInstanceUpdateUserProvided
    include ServiceInstanceCreateMixin

    class UnprocessableUpdate < ::StandardError
    end

    def initialize(service_event_repository)
      @service_event_repository = service_event_repository
    end

    def update(service_instance, message)
      logger = Steno.logger('cc.action.user_provided_service_instance_update')

      updates = {}
      updates[:name] = message.name if message.requested?(:name)
      updates[:credentials] = message.credentials if message.requested?(:credentials)
      updates[:syslog_drain_url] = message.syslog_drain_url if message.requested?(:syslog_drain_url)
      updates[:route_service_url] = message.route_service_url if message.requested?(:route_service_url)
      updates[:tags] = message.tags if message.requested?(:tags)

      last_operation = {
        type: 'update',
        state: 'succeeded',
        description: 'Operation succeeded'
      }

      service_instance.db.transaction do
        original_service_instance = service_instance.dup
        service_instance.save_with_new_operation(updates, last_operation)
        MetadataUpdate.update(service_instance, message)
        service_event_repository.record_user_provided_service_instance_event(:update, original_service_instance, message.audit_hash)
      end
      logger.info("Finished updating user-provided service_instance #{service_instance.guid}")
      service_instance
    rescue Sequel::ValidationFailed => e
      validation_error!(
        e,
        name: message.name,
        validation_error_handler: ValidationErrorHandler.new
      )
    end

    private

    attr_reader :service_event_repository

    class ValidationErrorHandler
      def error!(message)
        raise UnprocessableUpdate.new(message)
      end
    end
  end
end
