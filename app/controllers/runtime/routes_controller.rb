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
      to_many :apps

      # This to_many relationship is used only for the link, and explicitly sets
      # the route_for to any empty array. This is used in relation with
      # enumerate_route_mappings method to handle the route model already having
      # a route_mappings association.
      to_many :route_mappings, link_only: true, exclude_in: [:create, :update],
                               route_for: [], association_name: :app_route_mappings
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
    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:host, :domain_id, :port])
      if name_errors && name_errors.include?(:unique)
        return Errors::ApiError.new_from_details('RouteHostTaken', attributes['host'])
      end

      path_errors = e.errors.on([:host, :domain_id, :path, :port])
      if path_errors && path_errors.include?(:unique)
        return Errors::ApiError.new_from_details('RoutePathTaken', attributes['path'])
      end

      space_errors = e.errors.on(:space)
      if space_errors && space_errors.include?(:total_routes_exceeded)
        return Errors::ApiError.new_from_details('SpaceQuotaTotalRoutesExceeded')
      end

      org_errors = e.errors.on(:organization)
      if org_errors && org_errors.include?(:total_routes_exceeded)
        return Errors::ApiError.new_from_details('OrgQuotaTotalRoutesExceeded')
      end

      host_and_domain_taken_error = e.errors.on([:domain_id, :host])
      if host_and_domain_taken_error
        return Errors::ApiError.new_from_details('RouteInvalid',
                                                 'Routes for this host and domain have been reserved for another space.')
      end

      path_error = e.errors.on(:path)
      if path_error
        return path_errors(path_error, attributes)
      end

      service_instance_errors = e.errors.on(:service_instance)
      if service_instance_errors && service_instance_errors.include?(:route_binding_not_allowed)
        return Errors::ApiError.new_from_details('ServiceDoesNotSupportRoutes')
      end

      Errors::ApiError.new_from_details('RouteInvalid', e.errors.full_messages)
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
      raise VCAP::Errors::ApiError.new_from_details('AssociationNotEmpty', 'service_instance', route.class.table_name)
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

    # This method is an almost straight copy of
    # ModelController#enumerate_related. The only difference is that this method
    # needs control of the association_name used to lookup
    # model/dataset/controller
    get "#{path_guid}/route_mappings", :enumerate_route_mappings
    def enumerate_route_mappings(guid)
      path_name = :route_mappings
      association_name = :app_route_mappings

      obj = find_guid(guid)
      validate_access(:read, obj)

      associated_model = obj.class.association_reflection(association_name).associated_class

      associated_controller = VCAP::CloudController.controller_from_model_name(associated_model)
      associated_path = "#{self.class.url_for_guid(guid)}/#{path_name}"

      validate_access(:index, associated_model, { related_obj: obj, related_model: model })

      filtered_dataset =
        Query.filtered_dataset_from_query_params(
          associated_model,
          obj.user_visible_relationship_dataset(association_name,
                                                VCAP::CloudController::SecurityContext.current_user,
                                                SecurityContext.admin?),
                                                associated_controller.query_parameters,
                                                @opts
      )

      associated_controller_instance = CloudController::ControllerFactory.new(@config, @logger, @env, @params, @body, @sinatra).create_controller(associated_controller)

      associated_controller_instance.collection_renderer.render_json(
        associated_controller,
        filtered_dataset,
        associated_path,
        @opts,
        {}
      )
    end

    get "#{path}/reserved/domain/:domain_guid/host/:host", :route_reserved
    def route_reserved(domain_guid, host)
      validate_access(:reserved, model)
      domain = Domain[guid: domain_guid]
      if domain
        path = params['path']
        routes = Route.where(domain: domain, host: host)
        routes = routes.where(path: path) if path

        return [HTTP::NO_CONTENT, nil] if routes.count > 0
      end
      [HTTP::NOT_FOUND, nil]
    end

    def before_create
      super
      domain_guid = request_attrs['domain_guid']
      return if domain_guid.nil?

      validate_route(domain_guid)
    end

    def after_create(route)
      @route_event_repository.record_route_create(route, SecurityContext.current_user, SecurityContext.current_user_email, request_attrs)
    end

    def before_update(route)
      super
      if request_attrs['app'].nil?
        validate_route(route.domain.guid) if request_attrs['port'] != route.port
      else
        app = App.find(guid: request_attrs['app'])
        begin
          RouteMappingValidator.new(route, app).validate
        rescue RouteMappingValidator::AppInvalidError
          raise Errors::ApiError.new_from_details('AppNotFound', request_attrs['app'])
        rescue RouteMappingValidator::TcpRoutingDisabledError
          raise Errors::ApiError.new_from_details('TcpRoutingDisabled')
        end
      end
    end

    def after_update(route)
      @route_event_repository.record_route_update(route, SecurityContext.current_user, SecurityContext.current_user_email, request_attrs)
    end

    define_messages
    define_routes

    private

    attr_reader :app_event_repository, :route_event_repository

    def routing_api_client
      raise RoutingApi::Client::RoutingApiDisabled if @routing_api_client.nil?
      @routing_api_client
    end

    def overwrite_port!
      if @request_attrs['port']
        add_warning('Specified port ignored. Random port generated.')
      end

      domain = Domain[guid: request_attrs['domain_guid']]
      raise Errors::ApiError.new_from_details('RouteInvalid', 'Port is supported for domains of TCP router groups only.') if domain.router_group_guid.nil?

      begin
        router_group = routing_api_client.router_group(domain.router_group_guid)
      rescue RoutingApi::Client::RoutingApiDisabled
        raise Errors::ApiError.new_from_details('TcpRoutingDisabled')
      end

      reservable_ports = router_group.reservable_ports

      @request_attrs = @request_attrs.deep_dup

      generated_port = PortGenerator.new(@request_attrs).generate_port(reservable_ports)
      raise Errors::ApiError.new_from_details('OutOfRouterGroupPorts', router_group.name) if generated_port < 0
      @request_attrs['port'] = generated_port

      @request_attrs.freeze
    end

    def convert_flag_to_bool(flag)
      raise Errors::ApiError.new_from_details('InvalidRequest') unless ['true', 'false', nil].include? flag
      flag == 'true'
    end

    def validate_route(domain_guid)
      RouteValidator.new(@routing_api_client, domain_guid, assemble_route_attrs).validate
    rescue RouteValidator::ValidationError => e
      raise Errors::ApiError.new_from_details(e.class.name.demodulize, e.message)
    rescue RoutingApi::Client::RoutingApiDisabled
      raise Errors::ApiError.new_from_details('TcpRoutingDisabled')
    rescue RoutingApi::Client::RoutingApiUnavailable
      raise Errors::ApiError.new_from_details('RoutingApiUnavailable')
    rescue RoutingApi::Client::UaaUnavailable
      raise Errors::ApiError.new_from_details('UaaUnavailable')
    end

    def assemble_route_attrs
      port = request_attrs['port']
      host = request_attrs['host']
      path = request_attrs['path']
      { 'port' => port, 'host' => host, 'path' => path }
    end

    def self.path_errors(path_error, attributes)
      if path_error.include?(:single_slash)
        return Errors::ApiError.new_from_details('PathInvalid', 'the path cannot be a single slash')
      elsif path_error.include?(:missing_beginning_slash)
        return Errors::ApiError.new_from_details('PathInvalid', 'the path must start with a "/"')
      elsif path_error.include?(:path_contains_question)
        return Errors::ApiError.new_from_details('PathInvalid', 'illegal "?" character')
      elsif path_error.include?(:invalid_path)
        return Errors::ApiError.new_from_details('PathInvalid', attributes['path'])
      end
    end
    private_class_method :path_errors
  end
end
