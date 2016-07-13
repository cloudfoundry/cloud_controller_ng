require 'cloud_controller/app_services/app_observer_staging_helper'

module VCAP::CloudController
  module AppObserver
    class << self
      extend Forwardable

      def configure(stagers, runners)
        @stagers = stagers
        @runners = runners
      end

      def deleted(app)
        with_diego_communication_handling do
          if app.staging?
            @stagers.stager_for_app(app).stop_stage
          end
          @runners.runner_for_app(app).stop
        end
      end

      def updated(app)
        changes = app.previous_changes
        return unless changes

        with_diego_communication_handling do
          if changes.key?(:state) || changes.key?(:diego) || changes.key?(:enable_ssh) || changes.key?(:ports)
            react_to_state_change(app)
          elsif changes.key?(:instances)
            react_to_instances_change(app)
          end
        end
      end

      def routes_changed(app)
        with_diego_communication_handling do
          @runners.runner_for_app(app).update_routes if app.started? && app.active?
        end
      end

      private

      def react_to_state_change(app)
        if !app.started?
          @runners.runner_for_app(app).stop
          return
        end

        if app.needs_staging?
          @stagers.validate_app(app)
          AppObserverStagingHelper.stage_app(app)
        else
          @runners.runner_for_app(app).start
        end
      end

      def react_to_instances_change(app)
        @runners.runner_for_app(app).scale if app.started? && app.active?
      end

      def with_diego_communication_handling
        yield
      rescue Diego::Runner::CannotCommunicateWithDiegoError => e
        logger.error("failed communicating with diego backend: #{e.message}")
      end

      def logger
        @logger ||= Steno.logger('cc.app_observer')
      end
    end
  end
end
