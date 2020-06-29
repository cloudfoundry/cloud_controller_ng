module VCAP::CloudController
  class ServiceInstanceDeleteUserProvided
    class AssociationNotEmptyError < StandardError; end

    def initialize(event_repo)
      @service_event_repository = event_repo
    end

    def delete(service_instance)
      association_not_empty! if service_instance.has_bindings? || service_instance.has_keys?

      service_instance.db.transaction do
        service_instance.lock!
        service_instance.destroy
        service_event_repository.record_user_provided_service_instance_event(:delete, service_instance, {})
      end
    end

    private

    def association_not_empty!
      raise AssociationNotEmptyError.new
    end

    attr_reader :service_event_repository
  end
end
