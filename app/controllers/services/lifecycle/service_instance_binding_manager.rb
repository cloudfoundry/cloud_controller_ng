require 'actions/services/locks/lock_check'

module VCAP::CloudController
  class ServiceInstanceBindingManager
    class ServiceInstanceNotFound < StandardError; end
    class ServiceInstanceNotBindable < StandardError; end
    class ServiceInstanceAlreadyBoundToSameRoute < StandardError; end
    class RouteNotFound < StandardError; end
    class RouteBindingNotFound < StandardError; end
    class RouteServiceDisabled < StandardError; end
    class RouteServiceRequiresDiego < StandardError; end
    class RouteAlreadyBoundToServiceInstance < StandardError; end

    include VCAP::CloudController::LockCheck

    def initialize(access_validator, logger)
      @access_validator = access_validator
      @logger = logger
    end

    def create_route_service_instance_binding(route_guid, instance_guid, arbitrary_parameters, route_services_enabled)
      route = Route.find(guid: route_guid)
      raise RouteNotFound unless route

      instance = ServiceInstance.find(guid: instance_guid)

      raise ServiceInstanceNotFound unless instance
      raise ServiceInstanceNotBindable unless instance.bindable?
      raise ServiceInstanceAlreadyBoundToSameRoute if route.service_instance == instance
      raise RouteAlreadyBoundToServiceInstance if route.service_instance
      raise RouteServiceRequiresDiego if !route.all_apps_diego?
      raise RouteServiceDisabled if instance.route_service? && !route_services_enabled

      route_binding = RouteBinding.new
      route_binding.route = route
      route_binding.service_instance = instance

      @access_validator.validate_access(:update, instance)

      raise Sequel::ValidationFailed.new(route_binding) unless route_binding.valid?

      raw_attributes = bind(route_binding, arbitrary_parameters)
      attributes_to_update = {
        route_service_url: raw_attributes[:route_service_url]
      }

      route_binding.set(attributes_to_update)

      save_route_binding(route_binding)

      notify_diego(route_binding, attributes_to_update)

      services_event_repository.record_service_instance_event(:bind_route, route_binding.service_instance, { route_guid: route.guid })

      route_binding
    end

    def delete_route_service_instance_binding(route_guid, instance_guid)
      route = Route.find(guid: route_guid)
      raise RouteNotFound unless route

      instance = ServiceInstance.find(guid: instance_guid)
      raise ServiceInstanceNotFound unless instance

      route_binding = RouteBinding.find(service_instance: instance, route: route)
      raise RouteBindingNotFound unless route_binding

      @access_validator.validate_access(:update, route_binding.service_instance)
      delete_route_binding(route_binding)

      services_event_repository.record_service_instance_event(:unbind_route, route_binding.service_instance, { route_guid: route.guid })

      route_binding.notify_diego if route_binding.route_service_url
    end

    private

    def bind(binding_obj, arbitrary_parameters)
      raise_if_locked(binding_obj.service_instance)
      client = VCAP::Services::ServiceClientProvider.provide(binding: binding_obj)
      client.bind(binding_obj, arbitrary_parameters)
    end

    def mitigate_orphan(binding)
      orphan_mitigator = SynchronousOrphanMitigate.new(@logger)
      orphan_mitigator.attempt_unbind(binding)
    end

    def save_route_binding(route_binding)
      route_binding.db.transaction do
        route_binding.save
      end
    rescue => e
      @logger.error "Failed to save binding for route: #{route_binding.route.guid} and service instance: #{route_binding.service_instance.guid} with exception: #{e}"
      mitigate_orphan(route_binding)
      raise e
    end

    def delete_route_binding(route_binding)
      route_binding.db.transaction do
        errors = RouteBindingDelete.new.delete [route_binding]
        unless errors.empty?
          @logger.error "Failed to delete binding with guid: #{route_binding.guid} with errors: #{errors.map(&:message).join(',')}"
          raise errors.first
        end
      end
    end

    def notify_diego(route_binding, attributes_to_update)
      route_binding.notify_diego if attributes_to_update[:route_service_url]
    rescue => e
      @logger.error "Failed to update route: #{route_binding.route.guid} and service_instance: #{route_binding.service_instance.guid} with exception: #{e}"
      mitigate_orphan(route_binding)
      route_binding.destroy
      raise e
    end

    def services_event_repository
      ::CloudController::DependencyLocator.instance.services_event_repository
    end
  end
end
