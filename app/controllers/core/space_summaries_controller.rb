module VCAP::CloudController
  rest_controller :SpaceSummaries do
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

    def summary(guid)
      space = find_guid_and_validate_access(:read, guid)

      apps = {}
      space.apps.each do |app|
        apps[app.guid] = app_summary(app)
      end

      started_apps = space.apps.select(&:started?)
      unless started_apps.empty?
        health_manager_client.healthy_instances(started_apps).each do |app_guid, num|
          apps[app_guid][:running_instances] = num
        end
      end

      space.apps.each do |app|
        if app.stopped?
          apps[app.guid][:running_instances] = 0
        end
      end

      services_summary = space.service_instances.map do |instance|
        instance.as_summary_json
      end

      Yajl::Encoder.encode(
        :guid => space.guid,
        :name => space.name,
        :apps => apps.values,
        :services => services_summary,
      )
    end

    protected

    attr_reader :health_manager_client

    def inject_dependencies(dependencies)
      @health_manager_client = dependencies[:health_manager_client]
    end

    private

    def app_summary(app)
      {
        :guid => app.guid,
        :urls => app.routes.map(&:fqdn),
        :routes => app.routes.map(&:as_summary_json),
        :service_count => app.service_bindings_dataset.count,
        :service_names => app.service_bindings_dataset.map(&:service_instance).map(&:name),
        :running_instances => nil,
      }.merge(app.to_hash)
    end

    get "#{path_guid}/summary", :summary
  end
end
