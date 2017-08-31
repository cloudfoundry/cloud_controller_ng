require 'cloud_controller/diego/tps_instances_reporter'
require 'cloud_controller/diego/instances_reporter'

module VCAP::CloudController
  class InstancesReporters
    def number_of_starting_and_running_instances_for_process(app)
      reporter_for_app.number_of_starting_and_running_instances_for_process(app)
    rescue CloudController::Errors::InstancesUnavailable => e
      raise CloudController::Errors::ApiError.new_from_details('InstancesUnavailable', e.to_s)
    end

    def all_instances_for_app(app)
      reporter_for_app.all_instances_for_app(app)
    rescue CloudController::Errors::InstancesUnavailable => e
      raise CloudController::Errors::ApiError.new_from_details('InstancesUnavailable', e.to_s)
    end

    def crashed_instances_for_app(app)
      reporter_for_app.crashed_instances_for_app(app)
    rescue CloudController::Errors::InstancesUnavailable => e
      raise CloudController::Errors::ApiError.new_from_details('InstancesUnavailable', e.to_s)
    end

    def stats_for_app(app)
      reporter_for_app.stats_for_app(app)
    rescue CloudController::Errors::InstancesUnavailable
      raise CloudController::Errors::ApiError.new_from_details('StatsUnavailable', 'Stats server temporarily unavailable.')
    end

    def number_of_starting_and_running_instances_for_processes(apps)
      diego_reporter.number_of_starting_and_running_instances_for_processes(apps)
    end

    private

    def reporter_for_app
      diego_reporter
    end

    def diego_reporter
      @diego_reporter ||= begin
        if bypass_bridge?
          Diego::InstancesReporter.new(dependency_locator.bbs_instances_client, dependency_locator.traffic_controller_client)
        else
          Diego::TpsInstancesReporter.new(dependency_locator.tps_client)
        end
      end
    end

    def bypass_bridge?
      !!Config.config.get(:diego, :temporary_local_tps)
    end

    def dependency_locator
      CloudController::DependencyLocator.instance
    end
  end
end
