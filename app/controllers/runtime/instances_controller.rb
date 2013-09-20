module VCAP::CloudController
  rest_controller :Instances do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    def instances(guid)
      app = find_guid_and_validate_access(:read, guid)

      if app.staging_failed?
        raise VCAP::Errors::StagingError.new("cannot get instances since staging failed")
      elsif app.pending?
        raise VCAP::Errors::NotStaged
      end

      instances = DeaClient.find_all_instances(app)
      Yajl::Encoder.encode(instances)
    end

    get  "#{path_guid}/instances", :instances
  end
end
