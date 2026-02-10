require 'actions/staging_cancel'

module VCAP::CloudController
  module Diego
    class StagingCompletionHandler
      class MalformedDiegoResponseError < StandardError; end

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
        @success_parser ||= Membrane::SchemaParser.parse(&schema)
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

            V2::AppStop.stop(build.app, StagingCancel.new(stagers)) if with_start
          end
          Repositories::BuildEventRepository.record_build_failed(build, payload[:error][:id], payload[:error][:message])
        rescue StandardError => e
          logger.error(logger_prefix + 'saving-staging-result-failed',
                       staging_guid: build.guid,
                       response: payload,
                       error: e.message,
                       build: build.inspect,
                       droplet: droplet.inspect)
        end

        VCAP::AppLogEmitter.emit_error(build.app_guid, "Failed to stage build: #{payload[:error][:message]}")
      end

      # rubocop:todo Metrics/CyclomaticComplexity
      # with_start is true when v2 staging causes apps to start
      def handle_success(payload, with_start)
        begin
          if payload[:result] && !payload[:result].is_a?(Hash)
            # keeping the error format the same as Membrane errors
            raise MalformedDiegoResponseError.new('{ result => unexpected format }')
          end

          payload[:result][:process_types] ||= {} if payload[:result]
          self.class.success_parser.validate(payload)
        rescue Membrane::SchemaValidationError, MalformedDiegoResponseError => e
          logger.error(logger_prefix + 'success.invalid-message', staging_guid: build.guid, payload: payload, error: e.to_s)

          payload[:error] = { message: 'Malformed message from Diego stager', id: DEFAULT_STAGING_ERROR }
          handle_failure(payload, with_start)
          raise CloudController::Errors::ApiError.new_from_details('InvalidRequest')
        end

        raise CloudController::Errors::ApiError.new_from_details('InvalidRequest') if build.in_final_state?

        app = droplet.app
        no_process_types = payload[:result][:process_types].blank?
        no_app_command = app.newest_web_process&.command.blank?

        if no_process_types && no_app_command
          payload[:error] = { message: 'Start command not specified', id: DEFAULT_STAGING_ERROR }
          handle_failure(payload, with_start)
        else
          begin
            save_staging_result(payload)
          rescue StandardError => e
            logger.error(logger_prefix + 'saving-staging-result-failed',
                         staging_guid: build.guid,
                         response: payload,
                         error: e.message,
                         build: build.inspect,
                         droplet: droplet.inspect)
            return
          end

          Repositories::BuildEventRepository.record_build_staged(build, droplet)

          begin
            if with_start
              start_process
            else
              Repositories::AppUsageEventRepository.new.create_from_build(build, 'BUILDPACK_SET')
            end
          rescue SidecarSynchronizeFromAppDroplet::ConflictingSidecarsError => e
            payload[:error] = { message: e.message, id: DEFAULT_STAGING_ERROR }
            handle_failure(payload, with_start)
            return
          rescue StandardError => e
            logger.error(logger_prefix + 'starting-process-failed', staging_guid: build.guid, response: payload, error: e.message)
            return
          end

          BitsExpiration.new.expire_droplets!(app)
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def handle_missing_droplet!(payload)
        raise NotImplementedError
      end

      def start_process
        app         = droplet.app
        web_process = app.newest_web_process

        return if web_process.latest_droplet.guid != droplet.guid

        app.db.transaction do
          app.lock!

          app.update(droplet:)
          SidecarSynchronizeFromAppDroplet.synchronize(app)
          revision = RevisionResolver.update_app_revision(app, nil)

          app.processes.each do |process|
            process.lock!
            process.update(revision:) if revision
            Repositories::AppUsageEventRepository.new.create_from_process(process, 'BUILDPACK_SET')
          end
        end
        @runners.runner_for_process(web_process.reload).start
      end

      def error_parser
        @error_parser ||= Membrane::SchemaParser.parse do
          {
            error: {
              id: String,
              message: String
            }
          }
        end
      end

      def stagers
        CloudController::DependencyLocator.instance.stagers
      end
    end
  end
end
