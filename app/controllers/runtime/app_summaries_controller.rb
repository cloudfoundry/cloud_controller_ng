require 'controllers/runtime/mixins/find_process_through_app'

module VCAP::CloudController
  class AppSummariesController < RestController::ModelController
    include FindProcessThroughApp

    def self.dependencies
      [:instances_reporters]
    end

    path_base 'apps'
    model_class_name :ProcessModel
    self.not_found_exception_name = 'AppNotFound'

    get "#{path_guid}/summary", :summary
    def summary(guid)
      process = find_guid_and_validate_access(:read, guid)

      app_info = {
        'guid'              => process.app_guid,
        'name'              => process.name,
        'routes'            => process.routes.map(&:as_summary_json),
        'running_instances' => instances_reporters.number_of_starting_and_running_instances_for_process(process),
        'services'          => process.service_bindings.map { |service_binding| service_binding.service_instance.as_summary_json },
        'available_domains' => (process.space.organization.private_domains + SharedDomain.all).map(&:as_summary_json)
      }.merge(process.to_hash)

      app_info['environment_json'] = process.app.environment_variables

      MultiJson.dump(app_info)
    end

    protected

    attr_reader :instances_reporters

    def inject_dependencies(dependencies)
      super
      @instances_reporters = dependencies[:instances_reporters]
    end
  end
end
