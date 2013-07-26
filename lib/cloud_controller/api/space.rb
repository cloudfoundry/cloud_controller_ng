# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Space do
    permissions_required do
      full Permissions::CFAdmin
      full Permissions::OrgManager
      read   Permissions::SpaceManager
      update Permissions::SpaceManager
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute  :name,            String
      to_one     :organization
      to_many    :developers
      to_many    :managers
      to_many    :auditors
      to_many    :apps
      to_many    :domains
      to_many    :service_instances
      to_many    :app_events
      to_many    :events
    end

    query_parameters :name, :organization_guid, :developer_guid, :app_guid

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:organization_id, :name])
      if name_errors && name_errors.include?(:unique)
        Errors::SpaceNameTaken.new(attributes["name"])
      else
        Errors::SpaceInvalid.new(e.errors.full_messages)
      end
    end

    get "/v2/spaces/:guid/service_instances", :enumerate_service_instances

    def enumerate_service_instances(guid)
      space = find_id_and_validate_access(:read, guid)

      if params['return_user_provided_service_instances'] == 'true'
        model_class = Models::ServiceInstance
        relation_name = :service_instances
      else
        model_class = Models::ManagedServiceInstance
        relation_name = :managed_service_instances
      end

      service_instances = Query.filtered_dataset_from_query_params(model_class,
                                                                  space.user_visible_relationship_dataset(relation_name),
                                                                  ServiceInstance.query_parameters,
                                                                  @opts)
      service_instances.filter(space: space)

      RestController::Paginator.render_json(
        ServiceInstance,
        service_instances,
        "/v2/spaces/#{guid}/service_instances",
        @opts
      )
    end

  end
end
