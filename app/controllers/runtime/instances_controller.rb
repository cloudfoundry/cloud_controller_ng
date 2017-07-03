module VCAP::CloudController
  class InstancesController < RestController::ModelController
    def self.dependencies
      [:instances_reporters, :index_stopper]
    end

    path_base 'apps'
    model_class_name :ProcessModel
    self.not_found_exception_name = 'AppNotFound'

    get "#{path_guid}/instances", :instances

    def instances(guid)
      process = find_guid_and_validate_access(:read, guid)

      if process.staging_failed?
        reason = process.staging_failed_reason || 'StagingError'
        raise CloudController::Errors::ApiError.new_from_details(reason, 'cannot get instances since staging failed')
      elsif process.pending?
        raise CloudController::Errors::ApiError.new_from_details('NotStaged')
      end

      if process.stopped?
        msg = "Request failed for app: #{process.name}"
        msg << ' as the app is in stopped state.'

        raise CloudController::Errors::ApiError.new_from_details('InstancesError', msg)
      end

      instances = instances_reporters.all_instances_for_app(process)
      MultiJson.dump(instances)
    end

    delete "#{path_guid}/instances/:index", :kill_instance

    def kill_instance(guid, index)
      process = find_guid_and_validate_access(:update, guid)

      index_stopper.stop_index(process, index.to_i)
      [HTTP::NO_CONTENT, nil]
    end

    protected

    attr_reader :instances_reporters, :index_stopper

    def inject_dependencies(dependencies)
      super
      @instances_reporters = dependencies.fetch(:instances_reporters)
      @index_stopper       = dependencies.fetch(:index_stopper)
    end
  end
end
