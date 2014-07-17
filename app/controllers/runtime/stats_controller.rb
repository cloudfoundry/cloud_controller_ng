module VCAP::CloudController
  class StatsController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get  "#{path_guid}/stats", :stats
    def stats(guid, opts = {})
      app = find_guid_and_validate_access(:read, guid)

      if app.stopped?
        msg = "Request failed for app: #{app.name}"
        msg << " as the app is in stopped state."

        raise ApiError.new_from_details('StatsError', msg)
      end

      [HTTP::OK, MultiJson.dump(instances_reporter.stats_for_app(app))]
    end

    protected

    attr_reader :instances_reporter

    def inject_dependencies(dependencies)
      super
      @instances_reporter = dependencies[:instances_reporter]
    end
  end
end
