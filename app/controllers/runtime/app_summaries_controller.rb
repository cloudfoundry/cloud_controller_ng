module VCAP::CloudController
  class AppSummariesController < RestController::ModelController
    def self.dependencies
      [:instances_reporters]
    end

    path_base 'apps'
    model_class_name :App

    get "#{path_guid}/summary", :summary
    def summary(guid)
      app = find_guid_and_validate_access(:read, guid)

      app_info = {
        'guid'              => app.guid,
        'name'              => app.name,
        'routes'            => app.routes.map(&:as_summary_json),
        'running_instances' => instances_reporters.number_of_starting_and_running_instances_for_app(app),
        'services'          => app.service_bindings.map { |service_binding| service_binding.service_instance.as_summary_json },
        'available_domains' => (app.space.organization.private_domains + SharedDomain.all).map(&:as_summary_json)
      }.merge(app.to_hash)

      MultiJson.dump(app_info)

    rescue Errors::InstancesUnavailable => e
      raise VCAP::Errors::ApiError.new_from_details('InstancesUnavailable', e.to_s)
    end

    protected

    attr_reader :instances_reporters

    def inject_dependencies(dependencies)
      super
      @instances_reporters = dependencies[:instances_reporters]
    end
  end
end
