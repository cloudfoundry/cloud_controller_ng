require 'cloud_controller/diego/processes_sync'
require 'cloud_controller/diego/tasks_sync'
require 'statsd'
require 'cloud_controller/copilot/sync'

module VCAP::CloudController
  module Jobs
    module Diego
      class Sync < VCAP::CloudController::Jobs::CCJob
        def initialize(statsd=Statsd.new, prometheus_updater=VCAP::CloudController::Metrics::PrometheusUpdater.new)
          @statsd = statsd
          @prometheus_updater = prometheus_updater
        end

        def perform
          config = CloudController::DependencyLocator.instance.config
          begin
            ## TODO: At some point in the future, start using a monotonic time source, rather than wall-clock time!
            start = Time.now
            VCAP::CloudController::Diego::ProcessesSync.new(config: config).sync
            VCAP::CloudController::Diego::TasksSync.new(config: config).sync
          ensure
            finish = Time.now
            ## NOTE: We're taking time in seconds and multiplying by 1000 because we don't have
            ##       access to time in milliseconds. If you ever get access to reliable time in
            ##       milliseconds, then do know that the lack of precision here is not desired
            ##       so feed in the entire value!
            elapsed_ms = ((finish - start) * 1000).round

            @statsd.timing('cc.diego_sync.duration', elapsed_ms)
            @prometheus_updater.report_diego_cell_sync_duration(elapsed_ms)
          end
        end

        private

        def logger
          @logger ||= Steno.logger('cc.diego.sync.perform')
        end
      end
    end
  end
end
