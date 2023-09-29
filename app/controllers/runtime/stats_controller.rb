require 'controllers/runtime/mixins/find_process_through_app'

module VCAP::CloudController
  class StatsController < RestController::ModelController
    include FindProcessThroughApp

    def self.dependencies
      [:instances_reporters]
    end

    path_base 'apps'
    model_class_name :ProcessModel
    self.not_found_exception_name = 'AppNotFound'

    get "#{path_guid}/stats", :stats

    def stats(guid, _opts={})
      process = find_guid_and_validate_access(:read, guid)

      raise ApiError.new_from_details('AppStoppedStatsError', process.name) if process.stopped?

      begin
        stats, warnings = instances_reporters.stats_for_app(process)

        warnings.each do |warning_message|
          add_warning(warning_message)
        end

        stats.each_value do |stats_hash|
          stats_hash[:stats].delete_if { |key, _| key == :net_info } if stats_hash[:stats]
        end
        [HTTP::OK, MultiJson.dump(stats)]
      rescue CloudController::Errors::ApiError => e
        raise e
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
