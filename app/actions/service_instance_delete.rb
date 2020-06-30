module VCAP::CloudController
  class ServiceInstanceDelete
    class AssociationNotEmptyError < StandardError; end
    class InstanceSharedError < StandardError; end
    class NotImplementedError < StandardError; end

    def initialize(event_repo)
      @service_event_repository = event_repo
    end

    def delete(service_instance)
      association_not_empty! if service_instance.has_bindings? || service_instance.has_keys? || service_instance.has_routes?

      cannot_delete_shared_instances! if service_instance.shared?

      case service_instance
      when ManagedServiceInstance
        raise NotImplementedError
      end

      service_instance.db.transaction do
        service_instance.lock!
        service_instance.destroy
        service_event_repository.record_user_provided_service_instance_event(:delete, service_instance, {})
      end
    end

    private

    def association_not_empty!
      raise AssociationNotEmptyError
    end

    def cannot_delete_shared_instances!
      raise InstanceSharedError
    end

    attr_reader :service_event_repository
  end
end
