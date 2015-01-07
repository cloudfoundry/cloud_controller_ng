module VCAP::CloudController
  class CrashesController < RestController::ModelController
    def self.dependencies
      [:instances_reporters]
    end

    path_base 'apps'
    model_class_name :App

    get "#{path_guid}/crashes", :crashes
    def crashes(guid)
      app = find_guid_and_validate_access(:read, guid)
      crashed_instances = instances_reporters.crashed_instances_for_app(app)
      MultiJson.dump(crashed_instances)
    end

    protected

    attr_reader :instances_reporters

    def inject_dependencies(dependencies)
      super
      @instances_reporters = dependencies[:instances_reporters]
    end
  end
end
