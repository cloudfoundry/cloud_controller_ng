module VCAP::CloudController
  class SpaceSummariesController < RestController::ModelController
    def self.dependencies
      [:instances_reporters]
    end

    path_base 'spaces'

    model_class_name :Space

    get "#{path_guid}/summary", :summary
    def summary(guid)
      space = find_guid_and_validate_access(:read, guid)

      MultiJson.dump(space_summary(space), pretty: true)
    end

    protected

    attr_reader :instances_reporters

    def inject_dependencies(dependencies)
      super
      @instances_reporters = dependencies[:instances_reporters]
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
      instances = instances_reporters.number_of_starting_and_running_instances_for_processes(space.apps)
      space.apps.collect do |app|
        {
          guid:              app.guid,
          urls:              app.routes.map(&:uri),
          routes:            app.routes.map(&:as_summary_json),
          service_count:     app.service_bindings_dataset.count,
          service_names:     app.service_bindings_dataset.map(&:service_instance).map(&:name),
          running_instances: instances[app.guid],
        }.merge(app.to_hash)
      end
    rescue CloudController::Errors::InstancesUnavailable => e
      raise CloudController::Errors::ApiError.new_from_details('InstancesUnavailable', e.to_s)
    end

    def services_summary(space)
      space.service_instances.map(&:as_summary_json)
    end
  end
end
