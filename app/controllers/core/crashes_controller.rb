module VCAP::CloudController
  rest_controller :Crashes do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    def crashes(guid)
      app = find_guid_and_validate_access(:read, guid)
      Yajl::Encoder.encode(health_manager_client.find_crashes(app))
    end

    get  "#{path_guid}/crashes", :crashes

    protected

    attr_reader :health_manager_client

    def inject_dependencies(dependencies)
      @health_manager_client = dependencies[:health_manager_client]
    end
  end
end
