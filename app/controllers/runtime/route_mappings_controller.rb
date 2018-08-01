require 'actions/v2/route_mapping_create'

module VCAP::CloudController
  class RouteMappingsController < RestController::ModelController
    define_attributes do
      to_one :app, exclude_in: [:update], association_name: :process
      to_one :route, exclude_in: [:update]
      attribute :app_port, Integer, default: nil, exclude_in: [:update]
    end

    model_class_name :RouteMappingModel

    query_parameters :app_guid, :route_guid

    def read(guid)
      obj = find_guid(guid)
      raise CloudController::Errors::ApiError.new_from_details('RouteMappingNotFound', guid) unless obj.process_type == 'web'
      validate_access(:read, obj)
      object_renderer.render_json(self.class, obj, @opts)
    end

    def create
      json_msg       = self.class::CreateMessage.decode(body)
      @request_attrs = json_msg.extract(stringify_keys: true)
      logger.debug 'cc.create', model: self.class.model_class_name, attributes: redact_attributes(:create, request_attrs)

      route   = Route.where(guid: request_attrs['route_guid']).eager(:space).all.first
      process = App.where(guid: request_attrs['app_guid']).eager(app: :space).all.first

      raise CloudController::Errors::ApiError.new_from_details('RouteNotFound', request_attrs['route_guid']) unless route
      raise CloudController::Errors::ApiError.new_from_details('AppNotFound', request_attrs['app_guid']) unless process
      raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') unless Permissions.new(SecurityContext.current_user).can_write_to_space?(process.space.guid)

      route_mapping = V2::RouteMappingCreate.new(SecurityContext.current_user, SecurityContext.current_user_email, route, process).add(request_attrs)

      if !request_attrs.key?('app_port') && !process.ports.blank?
        add_warning("Route has been mapped to app port #{route_mapping.app_port}.")
      end

      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{route_mapping.guid}" },
        object_renderer.render_json(self.class, route_mapping, @opts)
      ]

    rescue RouteMappingCreate::DuplicateRouteMapping
      raise CloudController::Errors::ApiError.new_from_details('RouteMappingTaken', route_mapping_taken_message(request_attrs))
    rescue RouteMappingCreate::UnavailableAppPort
      raise CloudController::Errors::ApiError.new_from_details('RoutePortNotEnabledOnApp')
    rescue V2::RouteMappingCreate::TcpRoutingDisabledError
      raise CloudController::Errors::ApiError.new_from_details('TcpRoutingDisabled')
    rescue V2::RouteMappingCreate::RouteServiceNotSupportedError
      raise CloudController::Errors::InvalidRelation.new('Route services are only supported for apps on Diego')
    rescue V2::RouteMappingCreate::AppPortNotSupportedError
      raise CloudController::Errors::ApiError.new_from_details('AppPortMappingRequiresDiego')
    rescue RouteMappingCreate::SpaceMismatch => e
      raise CloudController::Errors::InvalidRelation.new(e.message)
    end

    def delete(guid)
      route_mapping = RouteMappingModel.where(guid: guid).eager(:route, :process, app: :space).all.first

      raise CloudController::Errors::ApiError.new_from_details('RouteMappingNotFound', guid) unless route_mapping
      raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') unless Permissions.new(SecurityContext.current_user).can_write_to_space?(route_mapping.space.guid)

      RouteMappingDelete.new(SecurityContext.current_user, SecurityContext.current_user_email).delete(route_mapping)

      [HTTP::NO_CONTENT, nil]
    end

    def update(_guid)
      [HTTP::NOT_FOUND]
    end

    define_messages
    define_routes

    private

    def filter_dataset(dataset)
      dataset.where("#{RouteMappingModel.table_name}__process_type".to_sym => 'web')
    end

    def get_app_port(app_guid, app_port)
      if app_port.blank?
        app = App.find(guid: app_guid)
        if !app.nil?
          return app.ports[0] unless app.ports.blank?
        end
      end

      app_port
    end

    def route_mapping_taken_message(request_attrs)
      app_guid = request_attrs['app_guid']
      route_guid = request_attrs['route_guid']
      app_port = get_app_port(app_guid, request_attrs['app_port'])

      error_message =  "Route #{route_guid} is mapped to "
      error_message += "port #{app_port} of " unless app_port.blank?
      error_message += "app #{app_guid}"

      error_message
    end
  end
end
