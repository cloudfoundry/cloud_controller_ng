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
      space.apps.reject { |process| process.app.nil? }.collect do |process|
        {
          guid:              process.app_guid,
          urls:              process.routes.map(&:uri),
          routes:            process.routes.map(&:as_summary_json),
          service_count:     process.service_bindings_dataset.count,
          service_names:     process.service_bindings_dataset.map(&:service_instance).map(&:name),
          running_instances: instances[process.guid],
        }.merge(process.to_hash)
      end
    end

    def services_summary(space)
      shared_summary = space.service_instances_shared_from_other_spaces.map { |s| shared_service_instance_summary(s) }
      source_summary = space.service_instances.map { |s| source_service_instance_summary(s) }

      shared_summary + source_summary
    end

    def shared_service_instance_summary(service_instance)
      service_instance.as_summary_json.merge('shared_from' => {
        'space_guid' => service_instance.space.guid,
        'space_name' => service_instance.space.name,
        'organization_name' => service_instance.space.organization.name,
      })
    end

    def source_service_instance_summary(service_instance)
      service_instance.as_summary_json.merge('shared_to' => shared_to_summary(service_instance))
    end

    def shared_to_summary(service_instance)
      service_instance.shared_spaces.map do |s|
        {
          'space_guid' => s.guid,
          'space_name' => s.name,
          'organization_name' => s.organization.name
        }
      end
    end
  end
end
