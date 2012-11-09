# Copyright (c) 2009-2011 VMware, Inc.

module VCAP::CloudController
  rest_controller :AppSummary do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::OrgManager
      read Permissions::SpaceManager
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    def summary(id)
      app = find_id_and_validate_access(:read, id)
      app_info = {
        :guid => app.guid,
        :name => app.name,
        :urls => app.routes.map(&:fqdn),
        :framework => app.framework.to_hash.merge(:guid => app.framework.guid),
        :runtime => app.runtime.to_hash.merge(:guid => app.runtime.guid),
        :running_instances => app.running_instances,
        :services => app.service_instances.map do |instance|
          {
            :guid => instance.guid,
            :service_guid => instance.service_plan.service.guid,
            :label => instance.service_plan.service.label,
            :provider => instance.service_plan.service.provider,
            :version => instance.service_plan.service.version,
            :plan_guid => instance.service_plan.guid,
            :plan_name => instance.service_plan.name,
          }
        end
      }.merge(app.to_hash)

      Yajl::Encoder.encode(app_info)
    end

    get "#{path_id}/summary", :summary
  end
end
