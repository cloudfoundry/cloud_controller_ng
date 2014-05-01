module VCAP::CloudController
  class InstancesController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get  "#{path_guid}/instances", :instances
    def instances(guid)
      app = find_guid_and_validate_access(:read, guid)

      if app.staging_failed?
        raise VCAP::Errors::ApiError.new_from_details("StagingError", "cannot get instances since staging failed")
      elsif app.pending?
        raise VCAP::Errors::ApiError.new_from_details("NotStaged")
      end

      if app.stopped?
        msg = "Request failed for app: #{app.name}"
        msg << " as the app is in stopped state."

        raise VCAP::Errors::ApiError.new_from_details("InstancesError", msg)
      end

      instances = DeaClient.find_all_instances(app)
      Yajl::Encoder.encode(instances)
    end
  end
end
