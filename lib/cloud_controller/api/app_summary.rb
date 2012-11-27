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
          service_instance_summary(instance)
        end
      }.merge(app.to_hash)

      Yajl::Encoder.encode(app_info)
    end

    private

    def service_instance_summary(instance)
      {
        :guid => instance.guid,
        :name => instance.name,
        :bound_app_count => instance.service_bindings_dataset.count,
        :service_plan => {
          :guid => instance.service_plan.guid,
          :name => instance.service_plan.name,
          :service => {
            :guid => instance.service_plan.service.guid,
            :label => instance.service_plan.service.label,
            :provider => instance.service_plan.service.provider,
            :version => instance.service_plan.service.version,
          }
        }
      }
    end

    get "#{path_id}/summary", :summary
  end
end
