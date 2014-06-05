module VCAP::CloudController
  class StatsController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get  "#{path_guid}/stats", :stats
    def stats(guid, opts = {})
      app                = find_guid_and_validate_access(:read, guid)
      instances_reporter = instances_reporter_factory.instances_reporter_for_app(app)
      stats              = instances_reporter.stats_for_app(app, opts)
      [HTTP::OK, Yajl::Encoder.encode(stats)]
    end

    protected

    attr_reader :instances_reporter_factory

    def inject_dependencies(dependencies)
      super
      @instances_reporter_factory = dependencies[:instances_reporter_factory]
    end
  end
end
