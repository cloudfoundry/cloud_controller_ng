require 'actions/staging_cancel'

module VCAP::CloudController
  module Diego
    class StagingCompletionHandler
      DEFAULT_STAGING_ERROR = 'StagingError'.freeze

      attr_reader :droplet, :build

      def initialize(build, runners=CloudController::DependencyLocator.instance.runners)
        @build   = build
        @droplet = build.droplet
        @runners = runners
      end

      def logger_prefix
        raise NotImplementedError.new('implement this in the inherited class')
      end

      def logger
        @logger ||= Steno.logger('cc.stager')
      end

      def staging_complete(payload, with_start=false)
        logger.info(logger_prefix + 'finished', response: payload)

        if payload[:error]
          handle_failure(payload, with_start)
        else
          handle_missing_droplet!(payload) if droplet.nil?
          handle_success(payload, with_start) if droplet.present?
        end
      end

      def self.success_parser
        @staging_response_schema ||= Membrane::SchemaParser.parse(&schema)
      end

      private

      def handle_failure(payload, with_start)
        begin
          error_parser.validate(payload)
        rescue Membrane::SchemaValidationError => e
          logger.error(logger_prefix + 'failure.invalid-message', staging_guid: build.guid, payload: payload, error: e.to_s)

          payload[:error] = { message: 'Malformed message from Diego stager', id: DEFAULT_STAGING_ERROR }
          handle_failure(payload, with_start)

          raise CloudController::Errors::ApiError.new_from_details('InvalidRequest')
        end

        begin
          build.class.db.transaction do
            build.lock!
            build.fail_to_stage!(payload[:error][:id], payload[:error][:message])

            if with_start
              V2::AppStop.stop(build.app, StagingCancel.new(stagers))
            end
          end
        rescue => e
          logger.error(logger_prefix + 'saving-staging-result-failed', staging_guid: build.guid, response: payload, error: e.message)
        end

        Loggregator.emit_error(build.guid, "Failed to stage build: #{payload[:error][:message]}")
      end

      def handle_success(payload, with_start)
        begin
          payload[:result][:process_types] ||= {} if payload[:result]
          self.class.success_parser.validate(payload)
        rescue Membrane::SchemaValidationError => e
          logger.error(logger_prefix + 'success.invalid-message', staging_guid: build.guid, payload: payload, error: e.to_s)

          payload[:error] = { message: 'Malformed message from Diego stager', id: DEFAULT_STAGING_ERROR }
          handle_failure(payload, with_start)

          raise CloudController::Errors::ApiError.new_from_details('InvalidRequest')
        end

        raise CloudController::Errors::ApiError.new_from_details('InvalidRequest') if build.in_final_state?

        app = droplet.app
        requires_start_command = with_start && payload[:result][:process_types].blank? && app.processes.first.command.blank?

        if payload[:result][:process_types].blank? && !with_start
          payload[:error] = { message: 'No process types returned from stager', id: DEFAULT_STAGING_ERROR }
          handle_failure(payload, with_start)
        elsif requires_start_command
          payload[:error] = { message: 'Start command not specified', id: DEFAULT_STAGING_ERROR }
          handle_failure(payload, with_start)
        else
          begin
            save_staging_result(payload)
          rescue => e
            logger.error(logger_prefix + 'saving-staging-result-failed', staging_guid: build.guid, response: payload, error: e.message)
          end

          begin
            start_process if with_start
          rescue => e
            logger.error(logger_prefix + 'starting-process-failed', staging_guid: build.guid, response: payload, error: e.message)
          end

          BitsExpiration.new.expire_droplets!(app)
        end
      end

      def handle_missing_droplet!(payload)
        raise NotImplementedError
      end

      def start_process
        app         = droplet.app
        web_process = app.web_process

        return if web_process.latest_droplet.guid != droplet.guid

        app.db.transaction do
          app.lock!

          app.update(droplet: droplet)

          app.processes.each do |p|
            p.lock!
            Repositories::AppUsageEventRepository.new.create_from_process(p, 'BUILDPACK_SET')
          end
        end

        @runners.runner_for_app(web_process).start
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

      def stagers
        CloudController::DependencyLocator.instance.stagers
      end
    end
  end
end
