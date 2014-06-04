module VCAP::CloudController
  class SpaceSummariesController < RestController::ModelController
    path_base "spaces"
    model_class_name :Space

    get "#{path_guid}/summary", :summary
    def summary(guid)
      space = find_guid_and_validate_access(:read, guid)

      apps = {}
      space.apps.each do |app|
        apps[app.guid] = app_summary(app)
      end

      services_summary = space.service_instances.map do |instance|
        instance.as_summary_json
      end

      Yajl::Encoder.encode(
        guid: space.guid,
        name: space.name,
        apps: apps.values,
        services: services_summary,
      )
    end

    private

    def inject_dependencies(dependencies)
      super
      @instances_reporter = dependencies[:instances_reporter]
    end

    def app_summary(app)
      {
        guid: app.guid,
        urls: app.routes.map(&:fqdn),
        routes: app.routes.map(&:as_summary_json),
        service_count: app.service_bindings_dataset.count,
        service_names: app.service_bindings_dataset.map(&:service_instance).map(&:name),
        running_instances: @instances_reporter.number_of_starting_and_running_instances_for_app(app),
      }.merge(app.to_hash)
    end
  end
end
