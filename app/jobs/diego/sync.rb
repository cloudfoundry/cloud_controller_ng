require 'cloud_controller/diego/processes_sync'
require 'cloud_controller/diego/tasks_sync'
require 'statsd'

module VCAP::CloudController
  module Jobs
    module Diego
      class Sync < VCAP::CloudController::Jobs::CCJob
        def initialize(statsd=Statsd.new)
          @statsd = statsd
        end

        def perform
          config = CloudController::DependencyLocator.instance.config
          if config.get(:diego, :temporary_local_sync)
            @statsd.time('cc.diego_sync.duration') do
              VCAP::CloudController::Diego::ProcessesSync.new(config: config).sync
              VCAP::CloudController::Diego::TasksSync.new(config: config).sync
            end
          else
            logger.info('Skipping diego sync as the `diego.temporary_local_sync` manifest property is false')
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
