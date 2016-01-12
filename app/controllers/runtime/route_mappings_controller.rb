module VCAP::CloudController
  class RouteMappingsController < RestController::ModelController
    class ValidationError < StandardError
    end
    class RouteMappingTaken < ValidationError
    end

    define_attributes do
      to_one :app, exclude_in: [:update]
      to_one :route, exclude_in: [:update]
      attribute :app_port, Integer, default: nil
    end

    def self.translate_validation_exception(e, attributes)
      port_errors = e.errors.on(:app_port)
      if port_errors && port_errors.include?(:diego_only)
        Errors::ApiError.new_from_details('AppPortMappingRequiresDiego')
      elsif port_errors && port_errors.include?(:not_bound_to_app)
        Errors::ApiError.new_from_details('RoutePortNotEnabledOnApp')
      end
    end

    def before_create
      super
      app_guid = request_attrs['app_guid']
      route_guid = request_attrs['route_guid']
      app_port = get_app_port(app_guid)
      validate_route_mapping(app_guid, app_port, route_guid)
    rescue RouteMappingsController::ValidationError => e
      raise Errors::ApiError.new_from_details(e.class.name.demodulize, e.message)
    end

    def get_app_port(app_guid)
      app_port = request_attrs['app_port']
      if app_port.blank?
        app = App.find(guid: app_guid)
        if !app.nil?
          return app.ports[0] unless app.ports.blank?
        end
      end

      app_port
    end

    def validate_route_mapping(app_guid, app_port, route_guid)
      mappings = RouteMapping.dataset.select_all(RouteMapping.table_name).
        join(App.table_name, id: :app_id).
        join(Route.table_name, id: :route_mappings__route_id).
        where(:"#{RouteMapping.table_name}__app_port" => request_attrs['app_port'],
              :"#{App.table_name}__guid" => request_attrs['app_guid'],
              :"#{Route.table_name}__guid" => request_attrs['route_guid'])
      raise RouteMappingTaken.new("Route #{route_guid} mapped to app #{app_guid} with
                                   port #{app_port}") unless mappings.count == 0
    end

    define_messages
    define_routes
  end
end
