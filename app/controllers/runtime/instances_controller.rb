module VCAP::CloudController
  class InstancesController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get  "#{path_guid}/instances", :instances
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
  end
end
