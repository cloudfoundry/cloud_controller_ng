module VCAP::CloudController
  class CrashesController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get  "#{path_guid}/crashes", :crashes
    def crashes(guid)
      app = find_guid_and_validate_access(:read, guid)
      crashed_instances = instances_reporter.crashed_instances_for_app(app)
      MultiJson.dump(crashed_instances)
    end

    protected

    attr_reader :instances_reporter

    def inject_dependencies(dependencies)
      super
      @instances_reporter = dependencies[:instances_reporter]
    end
  end
end
