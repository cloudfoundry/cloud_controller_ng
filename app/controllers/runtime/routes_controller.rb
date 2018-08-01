require 'actions/routing/route_delete'

module VCAP::CloudController
  class RoutesController < RestController::ModelController
    define_attributes do
      attribute :host, String, default: ''
      attribute :path, String, default: nil
      attribute :port, Integer, default: nil
      to_one :domain
      to_one :space
      to_one :service_instance, exclude_in: [:create, :update]
      to_many :apps, route_for: :get, exclude_in: [:create, :update]
      to_many :route_mappings, link_only: true, exclude_in: [:create, :update], route_for: [:get], association_controller: :RouteMappingsController
    end

    query_parameters :host, :domain_guid, :organization_guid, :path, :port

    def self.dependencies
      [:app_event_repository, :routing_api_client, :route_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @app_event_repository = dependencies.fetch(:app_event_repository)
      @routing_api_client = dependencies.fetch(:routing_api_client)
      @route_event_repository = dependencies.fetch(:route_event_repository)
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/MethodLength
    def self.translate_validation_exception(e, attributes)
      if e.errors.on(:routing_api) == [:routing_api_disabled]
        return CloudController::Errors::ApiError.new_from_details('TcpRoutingDisabled')
      end

      if e.errors.on(:routing_api) == [:uaa_unavailable]
        return CloudController::Errors::ApiError.new_from_details('UaaUnavailable', 'The UAA service is currently unavailable')
      end

      if e.errors.on(:routing_api) == [:routing_api_unavailable]
        return CloudController::Errors::ApiError.new_from_details('RoutingApiUnavailable')
      end

      if e.errors.on(:port) == [:port_taken]
        port_taken_error_message = "Port #{attributes['port']} is not available on this domain's router group. " \
          'Try a different port, request an random port, or ' \
          'use a domain of a different router group.'

        return CloudController::Errors::ApiError.new_from_details('RoutePortTaken', port_taken_error_message)
      end

      if e.errors.on(:router_group)
        return CloudController::Errors::ApiError.new_from_details('RouterGroupNotFound', e.errors.on(:router_group))
      end

      if e.errors.on(:port) == [:port_unsupported]
        return CloudController::Errors::ApiError.new_from_details('RouteInvalid', 'Port is supported for domains of TCP router groups only.')
      end

      if e.errors.on(:port) == [:port_required]
        return CloudController::Errors::ApiError.new_from_details('RouteInvalid', 'For TCP routes you must specify a port or request a random one.')
      end

      if e.errors.on(:port) == [:port_unavailable]
        return CloudController::Errors::ApiError.new_from_details('RouteInvalid',
                 'The requested port is not available for reservation. ' \
                 'Try a different port or request a random one be generated for you.')
      end
      if e.errors.on(:host) == [:host_and_path_domain_tcp]
        return CloudController::Errors::ApiError.new_from_details('RouteInvalid', 'Host and path are not supported, as domain belongs to a TCP router group.')
      end

      name_errors = e.errors.on([:host, :domain_id])
      if name_errors && name_errors.include?(:unique)
        return CloudController::Errors::ApiError.new_from_details('RouteHostTaken', attributes['host'])
      end

      if e.errors.on(:host) == [:system_hostname_conflict]
        return CloudController::Errors::ApiError.new_from_details('RouteHostTaken',
                                                                  "#{attributes['host']} is a system domain")
      end

      path_errors = e.errors.on([:host, :domain_id, :path])
      if path_errors && path_errors.include?(:unique)
        return CloudController::Errors::ApiError.new_from_details('RoutePathTaken', attributes['path'])
      end

      space_errors = e.errors.on(:space)
      if space_errors && space_errors.include?(:total_routes_exceeded)
        return CloudController::Errors::ApiError.new_from_details('SpaceQuotaTotalRoutesExceeded')
      end

      if space_errors && space_errors.include?(:total_reserved_route_ports_exceeded)
        return CloudController::Errors::ApiError.new_from_details('SpaceQuotaTotalReservedRoutePortsExceeded')
      end

      org_errors = e.errors.on(:organization)
      if org_errors && org_errors.include?(:total_routes_exceeded)
        return CloudController::Errors::ApiError.new_from_details('OrgQuotaTotalRoutesExceeded')
      end

      if org_errors && org_errors.include?(:total_reserved_route_ports_exceeded)
        return CloudController::Errors::ApiError.new_from_details('OrgQuotaTotalReservedRoutePortsExceeded')
      end

      host_and_domain_taken_error = e.errors.on([:domain_id, :host])
      if host_and_domain_taken_error
        return CloudController::Errors::ApiError.new_from_details('RouteInvalid',
                                                 'Routes for this host and domain have been reserved for another space.')
      end

      path_error = e.errors.on(:path)
      if path_error
        return path_errors(path_error, attributes)
      end

      service_instance_errors = e.errors.on(:service_instance)
      if service_instance_errors && service_instance_errors.include?(:route_binding_not_allowed)
        return CloudController::Errors::ApiError.new_from_details('ServiceDoesNotSupportRoutes')
      end

      CloudController::Errors::ApiError.new_from_details('RouteInvalid', e.errors.full_messages)
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def create
      json_msg = self.class::CreateMessage.decode(body)

      @request_attrs = json_msg.extract(stringify_keys: true)

      logger.debug 'cc.create', model: self.class.model_class_name, attributes: redact_attributes(:create, request_attrs)

      overwrite_port! if convert_flag_to_bool(params['generate_port'])

      before_create

      route = model.create_from_hash(request_attrs)
      validate_access(:create, route, request_attrs)

      after_create(route)
      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{route.guid}" },
        object_renderer.render_json(self.class, route, @opts)
      ]
    end

    def delete(guid)
      route = find_guid_and_validate_access(:delete, guid)

      route_delete_action = RouteDelete.new(
        app_event_repository:   app_event_repository,
        route_event_repository: route_event_repository,
        user:                   SecurityContext.current_user,
        user_email:             SecurityContext.current_user_email)

      if async?
        job = route_delete_action.delete_async(route: route, recursive: recursive_delete?)
        [HTTP::ACCEPTED, JobPresenter.new(job).to_json]
      else
        route_delete_action.delete_sync(route: route, recursive: recursive_delete?)
        [HTTP::NO_CONTENT, nil]
      end
    rescue RouteDelete::ServiceInstanceAssociationError
      raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'service_instance', route.class.table_name)
    end

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      org_index = opts[:q].index { |query| query.start_with?('organization_guid:') } if opts[:q]
      orgs_index = opts[:q].index { |query| query.start_with?('organization_guid IN ') } if opts[:q]

      org_guids = []

      if org_index
        org_guid = opts[:q][org_index].split(':')[1]
        opts[:q].delete(opts[:q][org_index])
        org_guids += [org_guid]
      end

      if orgs_index
        org_guids += opts[:q][orgs_index].split(' IN ')[1].split(',')
        opts[:q].delete(opts[:q][orgs_index])
      end

      filtered_dataset = super(model, ds, qp, opts)

      if org_guids.any?
        filtered_dataset.
          select_all(:routes).
          left_join(:spaces, id: :routes__space_id).
          left_join(:organizations, id: :spaces__organization_id).
          where(organizations__guid: org_guids)
      else
        filtered_dataset
      end
    end

    get "#{path}/reserved/domain/:domain_guid", :route_reserved
    def route_reserved(domain_guid)
      host = params['host'] || ''
      path = params['path']
      port = params['port'] || 0

      check_route_reserved(domain_guid, host, path, port)
    end

    get "#{path}/reserved/domain/:domain_guid/host/:host", :http_route_reserved
    def http_route_reserved(domain_guid, host)
      path = params['path']
      check_route_reserved(domain_guid, host, path, nil)
    end

    def after_create(route)
      @route_event_repository.record_route_create(route, SecurityContext.current_user, SecurityContext.current_user_email, request_attrs)
    end

    def after_update(route)
      @route_event_repository.record_route_update(route, SecurityContext.current_user, SecurityContext.current_user_email, request_attrs)
    end

    put '/v2/routes/:route_guid/apps/:app_guid', :add_app
    def add_app(route_guid, app_guid)
      logger.debug 'cc.association.add', guid: route_guid, association: 'apps', other_guid: app_guid
      @request_attrs = { 'app' => app_guid, verb: 'add', relation: 'apps', related_guid: app_guid }

      route = find_guid(route_guid, Route)
      validate_access(:read_related_object_for_update, route, request_attrs)

      before_update(route)

      app = App.find(guid: request_attrs['app'])
      raise CloudController::Errors::ApiError.new_from_details('AppNotFound', app_guid) unless app

      begin
        V2::RouteMappingCreate.new(SecurityContext.current_user, SecurityContext.current_user_email, route, app).add(request_attrs)
      rescue RouteMappingCreate::DuplicateRouteMapping
        # the route is already mapped, consider the request successful
      rescue V2::RouteMappingCreate::TcpRoutingDisabledError
        raise CloudController::Errors::ApiError.new_from_details('TcpRoutingDisabled')
      rescue RouteMappingCreate::SpaceMismatch
        raise CloudController::Errors::InvalidAppRelation.new(app.guid)
      rescue V2::RouteMappingCreate::RouteServiceNotSupportedError
        raise CloudController::Errors::InvalidAppRelation.new("#{app.guid} - Route services are only supported for apps on Diego")
      end

      after_update(route)

      [HTTP::CREATED, object_renderer.render_json(self.class, route, @opts)]
    end

    delete '/v2/routes/:route_guid/apps/:app_guid', :remove_app
    def remove_app(route_guid, app_guid)
      logger.debug 'cc.association.remove', guid: route_guid, association: 'apps', other_guid: app_guid
      @request_attrs = { 'app' => app_guid, verb: 'remove', relation: 'apps', related_guid: app_guid }

      route = find_guid(route_guid, Route)
      validate_access(:can_remove_related_object, route, request_attrs)

      before_update(route)

      process = App.find(guid: request_attrs['app'])
      raise CloudController::Errors::ApiError.new_from_details('AppNotFound', app_guid) unless process

      route_mapping = RouteMappingModel.find(app: process.app, route: route, process: process)
      RouteMappingDelete.new(SecurityContext.current_user, SecurityContext.current_user_email).delete(route_mapping)

      after_update(route)

      [HTTP::NO_CONTENT]
    end

    define_messages
    define_routes

    private

    attr_reader :app_event_repository, :route_event_repository, :routing_api_client

    def check_route_reserved(domain_guid, host, path, port)
      validate_access(:reserved, model)
      domain = Domain[guid: domain_guid]
      if domain
        ds = domain.router_group_guid.present? ? Domain.where(router_group_guid: domain.router_group_guid) : domain

        routes = Route.where(domain: ds)
        routes = routes.where(host: host) if host
        routes = routes.where(path: path) if path
        routes = routes.where(port: port) if port

        return [HTTP::NO_CONTENT, nil] if routes.count > 0
      end
      [HTTP::NOT_FOUND, nil]
    end

    def domain_invalid!(domain_guid)
      raise CloudController::Errors::ApiError.new_from_details('DomainInvalid', "Domain with guid #{domain_guid} does not exist")
    end

    def overwrite_port!
      add_warning('Specified port ignored. Random port generated.') if @request_attrs['port']

      generated_port = PortGenerator.new(@request_attrs['domain_guid']).generate_port(validated_router_group.reservable_ports)
      raise CloudController::Errors::ApiError.new_from_details('OutOfRouterGroupPorts', validated_router_group.name) if generated_port < 0
      overwrite_request_attr('port', generated_port)
    end

    def validated_router_group
      @router_group ||=
        begin
          router_group = routing_api_client.router_group(validated_domain.router_group_guid)
          raise CloudController::Errors::ApiError.new_from_details('RouterGroupNotFound', validated_domain.router_group_guid.to_s) if router_group.nil?
          router_group
        rescue RoutingApi::RoutingApiDisabled
          raise CloudController::Errors::ApiError.new_from_details('TcpRoutingDisabled')
        end
    end

    def validated_domain
      domain_guid = @request_attrs['domain_guid']
      domain = Domain.find(guid: domain_guid)
      domain_invalid!(domain_guid) if domain.nil?

      unless domain.shared? && domain.tcp?
        raise CloudController::Errors::ApiError.new_from_details('RouteInvalid', 'Port is supported for domains of TCP router groups only.')
      end

      domain
    end

    def convert_flag_to_bool(flag)
      raise CloudController::Errors::ApiError.new_from_details('InvalidRequest') unless ['true', 'false', nil].include? flag
      flag == 'true'
    end

    def assemble_route_attrs
      port = request_attrs['port']
      host = request_attrs['host']
      path = request_attrs['path']
      { 'port' => port, 'host' => host, 'path' => path }
    end

    def self.path_errors(path_error, attributes)
      if path_error.include?(:single_slash)
        return CloudController::Errors::ApiError.new_from_details('PathInvalid', 'the path cannot be a single slash')
      elsif path_error.include?(:missing_beginning_slash)
        return CloudController::Errors::ApiError.new_from_details('PathInvalid', 'the path must start with a "/"')
      elsif path_error.include?(:path_contains_question)
        return CloudController::Errors::ApiError.new_from_details('PathInvalid', 'illegal "?" character')
      elsif path_error.include?(:path_exceeds_valid_length)
        return CloudController::Errors::ApiError.new_from_details('PathInvalid', 'the path exceeds 128 characters')
      elsif path_error.include?(:invalid_path)
        return CloudController::Errors::ApiError.new_from_details('PathInvalid', attributes['path'])
      end
    end
    private_class_method :path_errors
  end
end
