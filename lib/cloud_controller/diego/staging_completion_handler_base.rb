module VCAP::CloudController
  module Diego
    class StagingCompletionHandlerBase
      def initialize(runners, logger, logger_prefix)
        @runners = runners
        @logger = logger
        @logger_prefix = logger_prefix
      end

      def staging_complete(payload)
        logger.info(@logger_prefix + "finished", :response => payload)

        if payload["error"]
          handle_failure(payload)
        else
          handle_success(payload)
        end
      end

      private

      def handle_failure(payload)
        app = get_app(payload)
        return if app.nil?

        app.mark_as_failed_to_stage
        Loggregator.emit_error(app.guid, "Failed to stage application: #{payload["error"]}")
      end


      def handle_success(payload)
        app = get_app(payload)
        return if app.nil?

        already_staged = save_staging_result(app, payload)
        if !already_staged
           @runners.runner_for_app(app).start
        end
      end

      def get_app(payload)
        app = App.find(guid: payload["app_id"])
        if app == nil
          logger.error(@logger_prefix + "unknown-app", :response => payload)
          return
        end

        return app if staging_is_current(app, payload)
        nil
      end

      def staging_is_current(app, payload)
        if payload["task_id"] != app.staging_task_id
          logger.warn(
            @logger_prefix + "not-current",
            :response => payload,
            :current => app.staging_task_id)
          return false
        end

        return true
      end

      attr_reader :logger
    end
  end
end
