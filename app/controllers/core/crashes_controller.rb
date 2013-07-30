module VCAP::CloudController
  rest_controller :Crashes do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::SpaceDeveloper
    end

    def crashes(guid)
      app = find_guid_and_validate_access(:read, guid)
      Yajl::Encoder.encode(HealthManagerClient.find_crashes(app))
    end

    get  "#{path_guid}/crashes", :crashes
  end
end
