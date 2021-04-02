require 'cloud_controller/diego/reporters/instances_reporter'
require 'cloud_controller/diego/reporters/instances_stats_reporter'

module VCAP::CloudController
  class InstancesReporters
    def number_of_starting_and_running_instances_for_process(app)
      diego_reporter.number_of_starting_and_running_instances_for_process(app)
    rescue CloudController::Errors::InstancesUnavailable => e
      raise CloudController::Errors::ApiError.new_from_details('InstancesUnavailable', e.to_s)
    end

    def all_instances_for_app(app)
      diego_reporter.all_instances_for_app(app)
    rescue CloudController::Errors::InstancesUnavailable => e
      raise CloudController::Errors::ApiError.new_from_details('InstancesUnavailable', e.to_s)
    end

    def crashed_instances_for_app(app)
      diego_reporter.crashed_instances_for_app(app)
    rescue CloudController::Errors::InstancesUnavailable => e
      raise CloudController::Errors::ApiError.new_from_details('InstancesUnavailable', e.to_s)
    end

    def stats_for_app(app)
      diego_stats_reporter.stats_for_app(app)
    rescue CloudController::Errors::InstancesUnavailable
      raise CloudController::Errors::ApiError.new_from_details('StatsUnavailable', 'Stats server temporarily unavailable.')
    end

    def number_of_starting_and_running_instances_for_processes(apps)
      diego_reporter.number_of_starting_and_running_instances_for_processes(apps)
    end

    private

    def diego_reporter
      @diego_reporter ||= Diego::InstancesReporter.new(dependency_locator.bbs_instances_client)
    end

    def diego_stats_reporter
      client = if Config.config.get(:temporary_use_logcache)
                 dependency_locator.traffic_controller_compatible_logcache_client
               else
                 dependency_locator.traffic_controller_client
               end
      Diego::InstancesStatsReporter.new(dependency_locator.bbs_instances_client, client)
    end

    def dependency_locator
      CloudController::DependencyLocator.instance
    end
  end
end
