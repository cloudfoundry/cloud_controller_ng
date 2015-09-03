module VCAP::CloudController
  class RoutesController < RestController::ModelController
    define_attributes do
      attribute :host, String, default: ''
      attribute :path, String, default: nil
      to_one :domain
      to_one :space
      to_one :service_instance, exclude_in: [:create, :update]
      to_many :apps
    end

    query_parameters :host, :domain_guid, :organization_guid, :path

    # def after_create(route)
    #   create_service_binding(route) if route.service_instance
    # end
    #
    # def create_service_binding(route)
    #   binding_manager = ServiceInstanceBindingManager.new(@services_event_repository, self, logger)
    #   service_binding = binding_manager.create_route_service_instance_binding(route, route.service_instance)
    #   #@services_event_repository.record_service_binding_event(:create, service_binding)
    # rescue ServiceInstanceBindingManager::ServiceInstanceNotBindable
    #   raise VCAP::Errors::ApiError.new_from_details('UnbindableService')
    # end

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

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
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

    define_messages
    define_routes
  end

  private

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
end
