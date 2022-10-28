require 'actions/v2/route_mapping_create'
require 'models/helpers/process_types'
require 'fetchers/queries/route_mapping_query'

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
      route_mapping = RouteMappingModel.where(guid: guid).first
      raise CloudController::Errors::ApiError.new_from_details('RouteMappingNotFound', guid) unless route_mapping && route_mapping.process_type == ProcessTypes::WEB

      validate_access(:read, route_mapping)
      object_renderer.render_json(self.class, route_mapping, @opts)
    end

    def create
      json_msg       = self.class::CreateMessage.decode(body)
      @request_attrs = json_msg.extract(stringify_keys: true)
      logger.debug 'cc.create', model: self.class.model_class_name, attributes: redact_attributes(:create, request_attrs)

      route   = Route.where(guid: request_attrs['route_guid']).first
      process = AppModel.find(guid: request_attrs['app_guid']).try(:newest_web_process)
      permissions = Permissions.new(SecurityContext.current_user)

      raise CloudController::Errors::ApiError.new_from_details('RouteNotFound', request_attrs['route_guid']) unless route
      raise CloudController::Errors::ApiError.new_from_details('AppNotFound', request_attrs['app_guid']) unless process
      raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') unless permissions.can_write_to_active_space?(process.space.id)
      raise CloudController::Errors::ApiError.new_from_details('OrgSuspended') unless permissions.is_space_active?(process.space.id)

      route_mapping = V2::RouteMappingCreate.new(UserAuditInfo.from_context(SecurityContext), route, process, request_attrs, logger).add

      if !request_attrs.key?('app_port') && !process.ports.blank?
        add_warning("Route has been mapped to app port #{route_mapping.app_port}.")
      end

      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{route_mapping.guid}" },
        object_renderer.render_json(self.class, route_mapping, @opts)
      ]
    rescue ::VCAP::CloudController::V2::RouteMappingCreate::DuplicateRouteMapping
      raise CloudController::Errors::ApiError.new_from_details('RouteMappingTaken', route_mapping_taken_message(request_attrs))
    rescue ::VCAP::CloudController::V2::RouteMappingCreate::UnavailableAppPort
      raise CloudController::Errors::ApiError.new_from_details('RoutePortNotEnabledOnApp')
    rescue ::VCAP::CloudController::V2::RouteMappingCreate::RoutingApiDisabledError
      raise CloudController::Errors::ApiError.new_from_details('RoutingApiDisabled')
    rescue ::VCAP::CloudController::V2::RouteMappingCreate::SpaceMismatch => e
      raise CloudController::Errors::InvalidRelation.new(e.message)
    end

    def delete(guid)
      route_mapping = RouteMappingModel.where(guid: guid).first
      permissions = Permissions.new(SecurityContext.current_user)

      raise CloudController::Errors::ApiError.new_from_details('RouteMappingNotFound', guid) unless route_mapping
      raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') unless permissions.can_write_to_active_space?(route_mapping.space.id)
      raise CloudController::Errors::ApiError.new_from_details('OrgSuspended') unless permissions.is_space_active?(route_mapping.space.id)

      RouteMappingDelete.new(UserAuditInfo.from_context(SecurityContext)).delete(route_mapping)

      [HTTP::NO_CONTENT, nil]
    end

    def update(_guid)
      [HTTP::NOT_FOUND]
    end

    private

    def get_filtered_dataset_for_enumeration(model, dataset, query_params, opts)
      RouteMappingQuery.filtered_dataset_from_query_params(model, dataset, query_params, opts)
    end

    define_messages
    define_routes

    def filter_dataset(dataset)
      dataset.where("#{RouteMappingModel.table_name}__process_type".to_sym => ProcessTypes::WEB)
    end

    def get_app_port(process_guid, app_port)
      if app_port.blank?
        process = ProcessModel.find(guid: process_guid)
        if !process.nil? && !process.ports.blank?
          return process.ports[0]
        end
      end

      app_port
    end

    def route_mapping_taken_message(request_attrs)
      process_guid = request_attrs['app_guid']
      route_guid   = request_attrs['route_guid']
      app_port     = get_app_port(process_guid, request_attrs['app_port'])

      error_message = "Route #{route_guid} is mapped to "
      error_message += "port #{app_port} of " unless app_port.blank?
      error_message += "app #{process_guid}"

      error_message
    end
  end
end
