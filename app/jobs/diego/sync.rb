require 'cloud_controller/diego/processes_sync'
require 'cloud_controller/diego/tasks_sync'

module VCAP::CloudController
  module Jobs
    module Diego
      class Sync < VCAP::CloudController::Jobs::CCJob
        def perform
          config = CloudController::DependencyLocator.instance.config

          # The Locking model has its own DB connection defined in lib/cloud_controller/db.rb
          # For that reason, the transaction below is not effectively wrapping transactions that may happen nested in its
          # block. This is to work around the fact that Sequel doesn't let us manage the transactions ourselves with a
          # non-block syntax
          Locking.db.transaction do
            Locking[name: 'diego-sync'].lock!

            VCAP::CloudController::Diego::ProcessesSync.new(config).sync if config.fetch(:diego, {}).fetch(:temporary_local_sync, false)
            VCAP::CloudController::Diego::TasksSync.new(config).sync if config.fetch(:diego, {}).fetch(:temporary_local_sync, false)
          end
        end
      end
    end
  end
end
