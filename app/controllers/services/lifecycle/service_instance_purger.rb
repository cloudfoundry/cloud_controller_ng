require 'actions/v2/services/service_binding_delete'

module VCAP::CloudController
  class ServiceInstancePurger
    def initialize(event_repository)
      @event_repository = event_repository
    end

    def purge(service_instance)
      logger.info("purging service instance #{service_instance.guid}")

      service_instance.db.transaction do
        service_instance.routes.each do |route|
          route.route_binding.destroy
        end

        service_instance.service_bindings.each do |binding|
          binding.destroy
          Repositories::ServiceBindingEventRepository.record_delete(binding, @event_repository.user_audit_info)
        end

        service_instance.service_keys.each do |key|
          key.destroy
          @event_repository.record_service_key_event('delete', key, nil)
        end

        service_instance.shared_spaces.each do |target_space|
          Repositories::ServiceInstanceShareEventRepository.record_unshare_event(service_instance, target_space, @event_repository.user_audit_info)
        end

        service_instance.destroy
        @event_repository.record_service_instance_event('purge', service_instance, nil)
      end

      logger.info("successfully purged service instance #{service_instance.guid}")
    end

    def logger
      @logger ||= Steno.logger('cc.service_lifecycle.instance_purger')
    end
  end
end
