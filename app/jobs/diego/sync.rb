require 'cloud_controller/diego/processes_sync'
require 'cloud_controller/diego/tasks_sync'

module VCAP::CloudController
  module Jobs
    module Diego
      class Sync < VCAP::CloudController::Jobs::CCJob
        def perform
          config = CloudController::DependencyLocator.instance.config
          if config.dig(:diego, :temporary_local_sync)
            VCAP::CloudController::Diego::ProcessesSync.new(config).sync
            VCAP::CloudController::Diego::TasksSync.new(config).sync
          end
        end
      end
    end
  end
end
