# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Crashes do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::SpaceDeveloper
    end

    def crashes(id)
      app = find_id_and_validate_access(:read, id)
      Yajl::Encoder.encode(HealthManagerClient.find_crashes(app))
    end

    get  "#{path_id}/crashes", :crashes
  end
end
