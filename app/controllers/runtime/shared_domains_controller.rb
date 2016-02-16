module VCAP::CloudController
  class SharedDomainsController < RestController::ModelController
    def self.dependencies
      [:routing_api_client, :router_group_type_populating_collection_renderer]
    end

    define_attributes do
      attribute :name, String, exclude_in: :update
      attribute :router_group_guid, String, exclude_in: :update, default: nil
    end

    query_parameters :name

    def inject_dependencies(dependencies)
      super
      @routing_api_client = dependencies.fetch(:routing_api_client)
      @router_group_type_populating_collection_renderer = dependencies.fetch(:router_group_type_populating_collection_renderer)
    end

    def before_create
      router_group_guid = request_attrs['router_group_guid']
      return if router_group_guid.nil?

      begin
        router_groups = @routing_api_client.router_groups || []
      rescue RoutingApi::Client::RoutingApiUnavailable
        raise Errors::ApiError.new_from_details('RoutingApiUnavailable')
      rescue RoutingApi::Client::UaaUnavailable
        raise Errors::ApiError.new_from_details('UaaUnavailable')
      end

      unless router_groups.map(&:guid).include? router_group_guid
        raise Errors::ApiError.new_from_details('DomainInvalid', "router group guid '#{router_group_guid}' not found")
      end
    end

    def after_create(domain)
      super(domain)
      unless domain.nil?
        unless domain.router_group_guid.nil?
          rtr_grp = @routing_api_client.router_group(domain.router_group_guid)
          domain.router_group_types = rtr_grp.types unless rtr_grp.nil?
        end
      end
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    get '/v2/shared_domains', :enumerate_shared_domains
    def enumerate_shared_domains
      validate_access(:index, model)
      @router_group_type_populating_collection_renderer.render_json(
        self.class,
          get_filtered_dataset_for_enumeration(model, SharedDomain.dataset, self.class.query_parameters, @opts),
          self.class.path,
          @opts,
          {},
      )
    end

    get '/v2/shared_domains/:guid', :get_shared_domain
    def get_shared_domain(guid)
      domain = SharedDomain.find(guid: guid)
      validate_access(:read, domain)
      unless domain.router_group_guid.nil?
        rtr_grp = @routing_api_client.router_group(domain.router_group_guid)
        domain.router_group_types = rtr_grp.types unless rtr_grp.nil?
      end
      object_renderer.render_json(self.class, domain, @opts)
    end

    define_messages
    define_routes

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::ApiError.new_from_details('DomainNameTaken', attributes['name'])
      else
        Errors::ApiError.new_from_details('DomainInvalid', e.errors.full_messages)
      end
    end

    def self.not_found_exception_name
      :DomainNotFound
    end
  end
end
