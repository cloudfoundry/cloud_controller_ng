module VCAP::CloudController
  class ServiceInstanceStateUpdater
    def initialize(client, services_event_repository, delegate)
      @client = client
      @services_event_repository = services_event_repository
      @delegate = delegate
    end

    def update_instance_state(service_instance, request_attrs)
      attrs_to_update = @client.fetch_service_instance_state(service_instance)

      ServiceInstance.db.transaction do
        service_instance.lock!
        service_instance.save_with_operation(
          last_operation: attrs_to_update[:last_operation].slice(:state, :description)
        )

        if last_operation_succeeded?(service_instance)
          apply_proposed_changes(service_instance)
          record_event(service_instance, request_attrs) if @services_event_repository
        end
      end

      @delegate.retry_state_updater unless service_instance.terminal_state?
    rescue HttpRequestError, HttpResponseError, Sequel::Error => e
      logger = Steno.logger('cc-background')
      logger.error("There was an error while fetching the service instance operation state: #{e}")
      @delegate.retry_state_updater
    end

    private

    def last_operation_succeeded?(service_instance)
      service_instance.last_operation.state == 'succeeded'
    end

    def apply_proposed_changes(service_instance)
      if service_instance.last_operation.type == 'delete'
        service_instance.last_operation.destroy
        service_instance.destroy
      else
        service_instance.save_with_operation(service_instance.last_operation.proposed_changes)
      end
    end

    def record_event(service_instance, request_attrs)
      type = service_instance.last_operation.type.to_sym
      @services_event_repository.record_service_instance_event(type, service_instance, request_attrs)
    end
  end
end
