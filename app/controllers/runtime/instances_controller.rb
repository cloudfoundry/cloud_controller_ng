module VCAP::CloudController
  class InstancesController < RestController::ModelController
    def self.dependencies
      [:instances_reporters, :index_stopper]
    end

    path_base 'apps'
    model_class_name :App

    get "#{path_guid}/instances", :instances
    def instances(guid)
      app = find_guid_and_validate_access(:read, guid)

      if app.staging_failed?
        reason = app.staging_failed_reason || 'StagingError'
        raise CloudController::Errors::ApiError.new_from_details(reason, 'cannot get instances since staging failed')
      elsif app.pending?
        raise CloudController::Errors::ApiError.new_from_details('NotStaged')
      end

      if app.stopped?
        msg = "Request failed for app: #{app.name}"
        msg << ' as the app is in stopped state.'

        raise CloudController::Errors::ApiError.new_from_details('InstancesError', msg)
      end

      instances = instances_reporters.all_instances_for_app(app)
      MultiJson.dump(instances)
    rescue CloudController::Errors::InstancesUnavailable => e
      raise CloudController::Errors::ApiError.new_from_details('InstancesUnavailable', e.to_s)
    end

    delete "#{path_guid}/instances/:index", :kill_instance
    def kill_instance(guid, index)
      app = find_guid_and_validate_access(:update, guid)

      index_stopper.stop_index(app, index.to_i)
      [HTTP::NO_CONTENT, nil]
    end

    protected

    attr_reader :instances_reporters, :index_stopper

    def inject_dependencies(dependencies)
      super
      @instances_reporters = dependencies.fetch(:instances_reporters)
      @index_stopper = dependencies.fetch(:index_stopper)
    end
  end
end
