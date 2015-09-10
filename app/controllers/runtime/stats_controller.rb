module VCAP::CloudController
  class StatsController < RestController::ModelController
    def self.dependencies
      [:instances_reporters]
    end

    path_base 'apps'
    model_class_name :App

    get "#{path_guid}/stats", :stats
    def stats(guid, opts={})
      app = find_guid_and_validate_access(:read, guid)

      if app.stopped?
        raise ApiError.new_from_details('AppStoppedStatsError', app.name)
      end

      begin
        [HTTP::OK, MultiJson.dump(instances_reporters.stats_for_app(app))]
      rescue Errors::InstancesUnavailable
        raise ApiError.new_from_details('StatsUnavailable', 'Stats server temporarily unavailable.')
      rescue StandardError => e
        raise ApiError.new_from_details('StatsError', e)
      end
    end

    protected

    attr_reader :instances_reporters

    def inject_dependencies(dependencies)
      super
      @instances_reporters = dependencies[:instances_reporters]
    end
  end
end
