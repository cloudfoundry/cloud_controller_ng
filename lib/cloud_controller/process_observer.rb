module VCAP::CloudController
  module ProcessObserver
    class << self
      extend Forwardable

      def configure(stagers, runners)
        @stagers = stagers
        @runners = runners
      end

      def deleted(process)
        with_diego_communication_handling do
          @runners.runner_for_process(process).stop
        end
      end

      def updated(process)
        changes = process.previous_changes
        return unless changes

        with_diego_communication_handling do
          if changes.key?(:state) || changes.key?(:diego) || changes.key?(:enable_ssh) || changes.key?(:ports)
            react_to_state_change(process)
          elsif changes.key?(:instances)
            react_to_instances_change(process)
          end
        end
      end

      private

      def react_to_state_change(process)
        unless process.started?
          @runners.runner_for_process(process).stop
          return
        end

        @runners.runner_for_process(process).start unless process.needs_staging?
      end

      def react_to_instances_change(process)
        @runners.runner_for_process(process).scale if process.started? && process.active?
      end

      def with_diego_communication_handling
        yield
      rescue Diego::Runner::CannotCommunicateWithDiegoError => e
        logger.error("Failed communicating with diego backend: #{e.message}. Continuing, sync job should eventually re-sync any desired changes to diego.")
      end

      def logger
        @logger ||= Steno.logger('cc.process_observer')
      end
    end
  end
end
