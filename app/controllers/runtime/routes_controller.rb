# rubocop:disable CyclomaticComplexity

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
    end

    query_parameters :host, :domain_guid, :organization_guid, :path, :port

    def self.dependencies
      [:routing_api_client, :route_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @routing_api_client = dependencies.fetch(:routing_api_client)
      @route_event_repository = dependencies.fetch(:route_event_repository)
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:host, :domain_id])
      if name_errors && name_errors.include?(:unique)
        return Errors::ApiError.new_from_details('RouteHostTaken', attributes['host'])
      end

      path_errors = e.errors.on([:host, :domain_id, :path])
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
      if !recursive_delete? && route.service_instance.present?
        raise VCAP::Errors::ApiError.new_from_details('AssociationNotEmpty', 'service_instance', route.class.table_name)
      end

      @route_event_repository.record_route_delete_request(route, SecurityContext.current_user, SecurityContext.current_user_email, recursive_delete?)

      do_delete(route)
    end

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      org_index = opts[:q].index { |query| query.start_with?('organization_guid:') } if opts[:q]
      if !org_index.nil?
        org_guid = opts[:q][org_index].split(':')[1]
        opts[:q].delete(opts[:q][org_index])

        super(model, ds, qp, opts).
          select_all(:routes).
          left_join(:spaces, id: :routes__space_id).
          left_join(:organizations, id: :spaces__organization_id).
          where(organizations__guid: org_guid)
      else
        super(model, ds, qp, opts)
      end
    end

    get "#{path}/reserved/domain/:domain_guid/host/:host", :route_reserved
    def route_reserved(domain_guid, host)
      validate_access(:reserved, model)
      domain = Domain[guid: domain_guid]
      if domain
        path = params['path']
        count = 0

        if path.nil?
          count = Route.where(domain: domain, host: host).count
        else
          count = Route.where(domain: domain, host: host, path: path).count
        end

        return [HTTP::NO_CONTENT, nil] if count > 0
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

      return if request_attrs['app']

      validate_route(route.domain.guid) if request_attrs['port'] != route.port
    end

    def after_update(route)
      @route_event_repository.record_route_update(route, SecurityContext.current_user, SecurityContext.current_user_email, request_attrs)
    end

    define_messages
    define_routes
  end

  private

  def overwrite_port!
    if @request_attrs['port']
      add_warning('Specified port ignored. Random port generated.')
    end

    @request_attrs = @request_attrs.deep_dup
    @request_attrs['port'] = PortGenerator.new(@request_attrs).generate_port
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
  rescue RoutingApi::Client::RoutingApiUnavailable
    raise Errors::ApiError.new_from_details('RoutingApiUnavailable')
  rescue RoutingApi::Client::UaaUnavailable
    raise Errors::ApiError.new_from_details('UaaUnavailable')
  end

  def path_errors(path_error, attributes)
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

  def assemble_route_attrs
    port = request_attrs['port']
    host = request_attrs['host']
    path = request_attrs['path']
    { 'port' => port, 'host' => host, 'path' => path }
  end
end
