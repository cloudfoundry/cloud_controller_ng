module VCAP::CloudController
  class SharedDomainsController < RestController::ModelController
    def self.dependencies
      [:routing_api_client]
    end

    define_attributes do
      attribute :name, String, exclude_in: :update
      attribute :router_group_guid, String, exclude_in: :update, default: nil
    end

    query_parameters :name

    def inject_dependencies(dependencies)
      super
      @routing_api_client = dependencies.fetch(:routing_api_client)
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

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
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
