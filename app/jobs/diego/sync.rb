require 'cloud_controller/diego/processes_sync'
require 'cloud_controller/diego/tasks_sync'

module VCAP::CloudController
  module Jobs
    module Diego
      class Sync < VCAP::CloudController::Jobs::CCJob
        def perform
          config = CloudController::DependencyLocator.instance.config
          if HashUtils.dig(config, :diego, :temporary_local_sync)
            VCAP::CloudController::Diego::ProcessesSync.new(config).sync
            VCAP::CloudController::Diego::TasksSync.new(config).sync
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
