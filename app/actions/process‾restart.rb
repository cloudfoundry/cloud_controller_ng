module VCAP::CloudController
  class ProcessRestart
    class << self
      def restart(process:, config:, stop_in_runtime:, revision: nil)
        need_to_stop_in_runtime = stop_in_runtime
        revision_to_set = revision || process.revision

        process.db.transaction do
          process.lock!
          process.skip_process_observer_on_update = true

          # A side-effect of submitting LRP requests before the transaction commits is that
          # the annotation timestamp stored on the LRP is slightly different than the process.updated_at
          # timestamp that is stored in the DB due to timestamp precision differences.
          # This difference causes the sync job to submit an extra update LRP request which updates
          # the LRP annotation at a later time. This should have no impact on the running LRP.
          if need_to_stop_in_runtime
            process.update(state: ProcessModel::STOPPED)
            runners(config).runner_for_process(process).stop
          end

          process.update(state: ProcessModel::STARTED, revision: revision_to_set)
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
