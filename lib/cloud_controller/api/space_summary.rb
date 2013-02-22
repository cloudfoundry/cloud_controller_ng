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

      apps = {}
      space.apps.each do |app|
        apps[app.guid] = app_summary(app)
      end

      started_apps = space.apps.select { |app| app.started? }
      unless started_apps.empty?
        HealthManagerClient.healthy_instances(started_apps).each do |guid, num|
          apps[guid][:running_instances] = num
        end
      end

      services_summary = space.service_instances.map do |instance|
        service_instance_summary(instance)
      end

      Yajl::Encoder.encode(
        :guid => space.guid,
        :name => space.name,
        :apps => apps.values,
        :services => services_summary,
      )
    end

    private

    def app_summary(app)
      {
        :guid => app.guid,
        :urls => app.routes.map(&:fqdn),
        :routes => app.routes.map(&:as_summary_json),
        :service_count => app.service_bindings_dataset.count,
        :framework_name => app.framework.name,
        :runtime_name => app.runtime.name,
        :running_instances => 0,
      }.merge(app.to_hash)
    end

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
