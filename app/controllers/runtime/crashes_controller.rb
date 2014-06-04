module VCAP::CloudController
  class CrashesController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get  "#{path_guid}/crashes", :crashes
    def crashes(guid)
      app = find_guid_and_validate_access(:read, guid)
      Yajl::Encoder.encode(health_manager_client.find_crashes(app))
    end

    protected

    attr_reader :health_manager_client

    def inject_dependencies(dependencies)
      super
      @health_manager_client = dependencies[:health_manager_client]
    end
  end
end
