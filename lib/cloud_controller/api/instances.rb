# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Instances do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::SpaceDeveloper
    end

    def instances(id)
      app = find_id_and_validate_access(:read, id)

      if app.failed?
        raise VCAP::Errors::StagingError.new("cannot get instances since staging failed")
      elsif app.pending?
        raise VCAP::Errors::StagingStillPending
      end

      instances = DeaClient.find_all_instances(app)
      Yajl::Encoder.encode(instances)
    end

    get  "#{path_id}/instances", :instances
  end
end
