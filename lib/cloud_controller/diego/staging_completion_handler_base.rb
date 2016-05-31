module VCAP::CloudController
  module Diego
    class StagingCompletionHandlerBase
      DEFAULT_STAGING_ERROR = 'StagingError'.freeze

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
          error_parser.validate(payload)
        rescue Membrane::SchemaValidationError => e
          logger.error('diego.staging.failure.invalid-message', staging_guid: staging_guid, payload: payload, error: e.to_s)
          raise CloudController::Errors::ApiError.new_from_details('InvalidRequest', payload)
        end

        process = get_process(staging_guid)
        return if process.nil?

        error   = payload[:error]
        id      = error[:id] || 'StagingError'
        message = error[:message]
        process.mark_as_failed_to_stage(id)
        Loggregator.emit_error(process.guid, "Failed to stage application: #{message}")
      end

      def get_process(staging_guid)
        app_guid = StagingGuid.process_guid(staging_guid)

        process = App.find(guid: app_guid)
        if process.nil?
          logger.error(@logger_prefix + 'unknown-app', staging_guid: staging_guid)
          return
        end

        return process if staging_is_current(process, staging_guid)
        nil
      end

      def staging_is_current(process, staging_guid)
        staging_task_id = StagingGuid.staging_task_id(staging_guid)
        if staging_task_id != process.staging_task_id
          logger.warn(
            @logger_prefix + 'not-current',
            staging_guid: staging_guid,
            current: process.staging_task_id)
          return false
        end

        true
      end

      def error_parser
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
