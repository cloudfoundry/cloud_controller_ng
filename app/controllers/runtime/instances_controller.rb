module VCAP::CloudController
  class InstancesController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get  "#{path_guid}/instances", :instances
    def instances(guid)
      app = find_guid_and_validate_access(:read, guid)

      if app.staging_failed?
        reason = app.staging_failed_reason || "StagingError"
        raise VCAP::Errors::ApiError.new_from_details(reason, "cannot get instances since staging failed")
      elsif app.pending?
        raise VCAP::Errors::ApiError.new_from_details("NotStaged")
      end

      if app.stopped?
        msg = "Request failed for app: #{app.name}"
        msg << " as the app is in stopped state."

        raise VCAP::Errors::ApiError.new_from_details("InstancesError", msg)
      end

      instances = instances_reporter.all_instances_for_app(app)
      MultiJson.dump(instances)
    end

    protected

    attr_reader :instances_reporter

    def inject_dependencies(dependencies)
      super
      @instances_reporter = dependencies.fetch(:instances_reporter)
    end
  end
end
