module VCAP::CloudController
  class RouteBinding < Sequel::Model
    plugin :after_initialize

    many_to_one :route
    many_to_one :service_instance

    export_attributes :route_service_url

    import_attributes :route_service_url

    delegate :service, :service_plan, :client, to: :service_instance

    def notify_diego
      route.apps.each do |app|
        app.handle_update_route(route) if app.diego
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
