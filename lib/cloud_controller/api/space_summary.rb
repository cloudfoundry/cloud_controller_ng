# Copyright (c) 2009-2011 VMware, Inc.

module VCAP::CloudController
  rest_controller :SpaceSummary do
    disable_default_routes
    path_base "spaces"
    model_class_name :Space

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::OrgManager
      read Permissions::SpaceManager
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    def summary(id)
      space = find_id_and_validate_access(:read, id)

      Yajl::Encoder.encode(
        :guid => space.guid,
        :name => space.name,
        :apps => space.apps.map do |app|
          {
            :guid => app.guid,
            :urls => app.routes.map(&:fqdn),
            :service_count => app.service_bindings_dataset.count,
          }.merge(app.to_hash)
        end,
        :services => space.service_instances.map do |instance|
          {
            :guid => instance.guid,
            :bound_app_count => instance.service_bindings_dataset.count,
            :service_guid => instance.service_plan.service.guid,
            :label => instance.service_plan.service.label,
            :provider => instance.service_plan.service.provider,
            :version => instance.service_plan.service.version,
            :plan_guid => instance.service_plan.guid,
            :plan_name => instance.service_plan.name,
          }
        end,
      )
    end

    get "#{path_id}/summary", :summary
  end
end
