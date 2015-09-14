require 'actions/services/locks/lock_check'

module VCAP::CloudController
  class RouteBindingDelete
    include VCAP::CloudController::LockCheck

    def delete(route_binding_dataset)
      route_binding_dataset.each_with_object([]) do |route_binding, errs|
        errs.concat delete_route_binding(route_binding)
      end
    end

    private

    def delete_route_binding(route_binding)
      errors = []
      service_instance = route_binding.service_instance

      begin
        raise_if_locked(service_instance)

        service_instance.client.unbind(service_binding)
        service_binding.destroy

      rescue => e
        errors << e
      end

      errors
    end
  end
end
