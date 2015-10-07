module VCAP::CloudController
  module Diego
    class StagingCompletionHandlerBase
      def initialize(runners, logger, logger_prefix)
        @runners = runners
        @logger = logger
        @logger_prefix = logger_prefix
      end

      def staging_complete(entity_or_id, payload)
        logger.info(@logger_prefix + 'finished', response: payload)

        if payload[:error]
          handle_failure(entity_or_id, payload)
        else
          handle_success(entity_or_id, payload)
        end
      end

      private

      def handle_failure(staging_guid, payload)
        begin
          self.class.error_parser.validate(payload)
        rescue Membrane::SchemaValidationError => e
          logger.error('diego.staging.failure.invalid-message', staging_guid: staging_guid, payload: payload, error: e.to_s)
          raise Errors::ApiError.new_from_details('InvalidRequest', payload)
        end

        app = get_app(staging_guid)
        return if app.nil?

        error   = payload[:error]
        id      = error[:id] || 'StagingError'
        message = error[:message]
        app.mark_as_failed_to_stage(id)
        Loggregator.emit_error(app.guid, "Failed to stage application: #{message}")
      end

      def handle_success(staging_guid, payload)
        app = get_app(staging_guid)
        return if app.nil?

        begin
          if payload[:result]
            payload[:result][:process_types] ||= {}
          end

          self.class.success_parser.validate(payload)
        rescue Membrane::SchemaValidationError => e
          logger.error('diego.staging.success.invalid-message', staging_guid: staging_guid, payload: payload, error: e.to_s)
          Loggregator.emit_error(app.guid, 'Malformed message from Diego stager')

          raise Errors::ApiError.new_from_details('InvalidRequest', payload)
        end

        begin
          save_staging_result(app, payload)
          @runners.runner_for_app(app).start
        rescue => e
          logger.error(@logger_prefix + 'saving-staging-result-failed', staging_guid: staging_guid, response: payload, error: e.message)
        end
      end

      def get_app(staging_guid)
        app_guid = StagingGuid.app_guid(staging_guid)

        app = App.find(guid: app_guid)
        if app.nil?
          logger.error(@logger_prefix + 'unknown-app', staging_guid: staging_guid)
          return
        end

        return app if staging_is_current(app, staging_guid)
        nil
      end

      def staging_is_current(app, staging_guid)
        staging_task_id = StagingGuid.staging_task_id(staging_guid)
        if staging_task_id != app.staging_task_id
          logger.warn(
            @logger_prefix + 'not-current',
            staging_guid: staging_guid,
            current: app.staging_task_id)
          return false
        end

        true
      end

      def self.error_parser
        @error_schema ||= Membrane::SchemaParser.parse do
          {
            error: {
              id: String,
              message: String,
            },
          }
        end
      end

      attr_reader :logger
    end
  end
end
