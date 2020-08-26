module VCAP::CloudController
  class RouteBinding < Sequel::Model
    plugin :after_initialize

    one_to_one :route_binding_operation

    many_to_one :route
    many_to_one :service_instance

    export_attributes :route_service_url

    import_attributes :route_service_url

    delegate :service, :service_plan, :client, to: :service_instance

    def notify_diego
      route.apps.each do |process|
        ProcessRouteHandler.new(process).notify_backend_of_route_update
      end
    end

    def after_initialize
      super
      self.guid ||= SecureRandom.uuid
    end

    def validate
      validates_presence :service_instance
      validates_presence :route
      validate_routing_service
      validate_space_match
    end

    def required_parameters
      { route: route.uri }
    end

    def last_operation
      route_binding_operation
    end

    def operation_in_progress?
      !!route_binding_operation && route_binding_operation.state == 'in progress'
    end

    def save_with_new_operation(attributes, last_operation)
      RouteBinding.db.transaction do
        self.lock!
        set(attributes)
        save_changes

        if self.last_operation
          self.last_operation.destroy
        end

        # it is important to create the service route binding operation with the service binding
        # instead of doing self.service_route_binding_operation = x
        # because mysql will deadlock when requests happen concurrently otherwise.
        RouteBindingOperation.create(last_operation.merge(route_binding_id: self.id))
        self.route_binding_operation(reload: true)
      end

      self
    end

    private

    def validate_routing_service
      return unless service_instance

      unless service_instance.route_service?
        errors.add(:service_instance, :route_binding_not_allowed)
      end
    end

    def validate_space_match
      return unless service_instance && route

      unless service_instance.space == route.space
        errors.add(:service_instance, :space_mismatch)
      end
    end
  end
end
