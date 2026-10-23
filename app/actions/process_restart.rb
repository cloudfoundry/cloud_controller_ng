module VCAP::CloudController
  class ProcessRestart
    class << self
      def restart(process:, config:, stop_in_runtime:, revision: nil)
        need_to_stop_in_runtime = stop_in_runtime
        revision_to_set = revision || process.revision

        process.db.transaction do
          process.lock!
          process.skip_process_observer_on_update = true

          if need_to_stop_in_runtime
            process.update(state: ProcessModel::STOPPED)
            runners(config).runner_for_process(process).stop
          end

          process.update(state: ProcessModel::STARTED, revision: revision_to_set, service_account_guid: process.app.service_account_guid, service_account_snapshot: true)
          runners(config).runner_for_process(process).start
        end
      end

      private

      def runners(config)
        Runners.new(config)
      end
    end
  end
end
