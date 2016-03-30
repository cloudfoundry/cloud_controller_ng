module VCAP::CloudController
  class RouteMappingsController < RestController::ModelController
    define_attributes do
      to_one :app, exclude_in: [:update]
      to_one :route, exclude_in: [:update]
      attribute :app_port, Integer, default: nil
    end

    query_parameters :app_guid, :route_guid

    def self.translate_validation_exception(e, attributes)
      port_errors = e.errors.on(:app_port)
      app_route_port_errors = e.errors.on([:app_id, :route_id, :app_port])
      app_route_errors = e.errors.on([:app_id, :route_id])

      if port_errors && port_errors.include?(:diego_only)
        Errors::ApiError.new_from_details('AppPortMappingRequiresDiego')
      elsif port_errors && port_errors.include?(:not_bound_to_app)
        Errors::ApiError.new_from_details('RoutePortNotEnabledOnApp')
      elsif app_route_port_errors && app_route_port_errors.include?(:unique)
        Errors::ApiError.new_from_details('RouteMappingTaken', route_mapping_taken_message(attributes))
      elsif app_route_errors && app_route_errors.include?(:unique)
        Errors::ApiError.new_from_details('RouteMappingTaken', route_mapping_taken_message(attributes))
      end
    end

    def before_create
      super

      route = Route.find(guid: request_attrs['route_guid'])
      app = App.find(guid: request_attrs['app_guid'])
      begin
        RouteMappingValidator.new(route, app).validate
      rescue RouteMappingValidator::AppInvalidError
        raise Errors::ApiError.new_from_details('AppNotFound', request_attrs['app_guid'])
      rescue RouteMappingValidator::RouteInvalidError
        raise Errors::ApiError.new_from_details('RouteNotFound', request_attrs['route_guid'])
      rescue RouteMappingValidator::TcpRoutingDisabledError
        raise Errors::ApiError.new_from_details('TcpRoutingDisabled')
      end
    end

    def after_create(route_mapping)
      super
      app_guid = request_attrs['app_guid']
      app_port = request_attrs['app_port']
      if app_port.blank?
        app = App.find(guid: app_guid)
        if !app.nil? && !app.ports.blank?
          port = app.ports[0]
          add_warning("Route has been mapped to app port #{port}.")
        end
      end
    end

    def delete(guid)
      route_mapping = find_guid_and_validate_access(:delete, guid)

      do_delete(route_mapping)
    end

    define_messages
    define_routes

    def self.get_app_port(app_guid, app_port)
      if app_port.blank?
        app = App.find(guid: app_guid)
        if !app.nil?
          return app.ports[0] unless app.ports.blank?
        end
      end

      app_port
    end
    private_class_method :get_app_port

    def self.route_mapping_taken_message(request_attrs)
      app_guid = request_attrs['app_guid']
      route_guid = request_attrs['route_guid']
      app_port = get_app_port(app_guid, request_attrs['app_port'])

      error_message =  "Route #{route_guid} is mapped to "
      error_message += "port #{app_port} of " unless app_port.blank?
      error_message += "app #{app_guid}"

      error_message
    end
    private_class_method :route_mapping_taken_message
  end
end
