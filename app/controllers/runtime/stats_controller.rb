module VCAP::CloudController
  class StatsController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get  "#{path_guid}/stats", :stats
    def stats(guid, opts = {})
      app                = find_guid_and_validate_access(:read, guid)

      if app.stopped?
        msg = "Request failed for app: #{app.name}"
        msg << " as the app is in stopped state."

        raise ApiError.new_from_details('StatsError', msg)
      end

      instances_reporter = instances_reporter_factory.instances_reporter_for_app(app)
      stats              = instances_reporter.stats_for_app(app)
      [HTTP::OK, MultiJson.dump(stats)]
    end

    protected

    attr_reader :instances_reporter_factory

    def inject_dependencies(dependencies)
      super
      @instances_reporter_factory = dependencies[:instances_reporter_factory]
    end
  end
end
