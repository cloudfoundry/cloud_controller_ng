module VCAP::CloudController
  class SpacesController < RestController::ModelController
    define_attributes do
      attribute  :name,            String
      to_one     :organization
      to_many    :developers
      to_many    :managers
      to_many    :auditors
      to_many    :apps
      to_many    :domains
      to_many    :service_instances
      to_many    :app_events,        :link_only => true
      to_many    :events,            :link_only => true
    end

    query_parameters :name, :organization_guid, :developer_guid, :app_guid

    deprecated_endpoint "#{path_guid}/domains/*"

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:organization_id, :name])
      if name_errors && name_errors.include?(:unique)
        Errors::SpaceNameTaken.new(attributes["name"])
      else
        Errors::SpaceInvalid.new(e.errors.full_messages)
      end
    end

    def inject_dependencies(dependencies)
      @space_event_repository = dependencies.fetch(:space_event_repository)
    end

    get "/v2/spaces/:guid/services", :enumerate_services
    def enumerate_services(guid)
      space = find_guid_and_validate_access(:read, guid)

      services = Query.filtered_dataset_from_query_params(
        Service,
        Service.organization_visible(space.organization),
        ServicesController.query_parameters,
        @opts
      )

      RestController::Paginator.render_json(
        ServicesController,
        services,
        "/v2/spaces/#{guid}/services",
        @opts.merge(serialization: ServiceSerialization, organization: space.organization)
      )
    end

    get "/v2/spaces/:guid/service_instances", :enumerate_service_instances
    def enumerate_service_instances(guid)
      space = find_guid_and_validate_access(:read, guid)

      if params['return_user_provided_service_instances'] == 'true'
        model_class = ServiceInstance
        relation_name = :service_instances
      else
        model_class = ManagedServiceInstance
        relation_name = :managed_service_instances
      end

      service_instances = Query.filtered_dataset_from_query_params(model_class,
        space.user_visible_relationship_dataset(relation_name, SecurityContext.current_user, SecurityContext.admin?),
        ServiceInstancesController.query_parameters,
        @opts)
      service_instances.filter(space: space)

      RestController::Paginator.render_json(
        ServiceInstancesController,
        service_instances,
        "/v2/spaces/#{guid}/service_instances",
        @opts
      )
    end

    def delete(guid)
      space = find_guid_and_validate_access(:delete, guid)
      @space_event_repository.record_space_delete_request(space, SecurityContext.current_user, recursive?)
      do_delete(space)
    end

    private
    def after_create(space)
      @space_event_repository.record_space_create(space, SecurityContext.current_user, request_attrs)
    end

    def after_update(space)
      @space_event_repository.record_space_update(space, SecurityContext.current_user, request_attrs)
    end

    module ServiceSerialization
      def self.to_hash(controller, service, opts)
        entity_hash = service.to_hash.merge({
          "service_plans" => service.service_plans_dataset.organization_visible(opts[:organization]).map do |service_plan|
            RestController::ObjectSerialization.to_hash(ServicePlansController, service_plan, opts)
          end
        })

        metadata_hash = {
          "guid" => service.guid,
          "url" => controller.url_for_guid(service.guid),
          "created_at" => service.created_at,
          "updated_at" => service.updated_at
        }

        {"metadata" => metadata_hash, "entity" => entity_hash}
      end
    end

    define_messages
    define_routes
  end
end
