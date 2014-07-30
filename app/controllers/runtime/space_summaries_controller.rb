module VCAP::CloudController
  class SpaceSummariesController < RestController::ModelController
    path_base "spaces"
    model_class_name :Space

    get "#{path_guid}/summary", :summary
    def summary(guid)
      space = find_guid_and_validate_access(:read, guid)

      MultiJson.dump(space_summary(space), pretty: true)
    end

    protected

    attr_reader :instances_reporter

    def inject_dependencies(dependencies)
      super
      @instances_reporter = dependencies[:instances_reporter]
    end

    private

    def space_summary(space)
      {
        guid:     space.guid,
        name:     space.name,
        apps:     app_summary(space),
        services: services_summary(space),
      }
    end

    def app_summary(space)
      instances = instances_reporter.number_of_starting_and_running_instances_for_apps(space.apps)
      space.apps.collect do |app|
        {
          guid:              app.guid,
          urls:              app.routes.map(&:fqdn),
          routes:            app.routes.map(&:as_summary_json),
          service_count:     app.service_bindings_dataset.count,
          service_names:     app.service_bindings_dataset.map(&:service_instance).map(&:name),
          running_instances: instances[app.guid],
        }.merge(app.to_hash)
      end
    rescue Errors::InstancesUnavailable => e
      raise VCAP::Errors::ApiError.new_from_details("InstancesUnavailable", e.to_s)
    end

    def services_summary(space)
      space.service_instances.map do |instance|
        instance.as_summary_json
      end
    end
  end
end
