module VCAP::CloudController
  class SpaceSummariesController < RestController::ModelController
    path_base "spaces"
    model_class_name :Space

    get "#{path_guid}/summary", :summary
    def summary(guid)
      space      = find_guid_and_validate_access(:read, guid)
      summarizer = SpaceSummarizer.new(space, instances_reporter_factory)

      Yajl::Encoder.encode(summarizer.space_summary, pretty: true)
    end

    protected

    attr_reader :instances_reporter_factory

    def inject_dependencies(dependencies)
      super
      @instances_reporter_factory = dependencies[:instances_reporter_factory]
    end
  end

  class SpaceSummarizer
    attr_reader :space, :instances_reporter_factory

    def initialize(space, instances_reporter_factory)
      @instances_reporter_factory = instances_reporter_factory
      @space                      = space
    end

    def space_summary
      {
        guid:     space.guid,
        name:     space.name,
        apps:     app_summary,
        services: services_summary,
      }
    end

    def app_summary
      space.apps.collect do |app|
        instances_reporter = instances_reporter_factory.instances_reporter_for_app(app)
        {
          guid:              app.guid,
          urls:              app.routes.map(&:fqdn),
          routes:            app.routes.map(&:as_summary_json),
          service_count:     app.service_bindings_dataset.count,
          service_names:     app.service_bindings_dataset.map(&:service_instance).map(&:name),
          running_instances: instances_reporter.number_of_starting_and_running_instances_for_app(app),
        }.merge(app.to_hash)
      end
    end

    def services_summary
     space.service_instances.map do |instance|
        instance.as_summary_json
      end
    end
  end
end