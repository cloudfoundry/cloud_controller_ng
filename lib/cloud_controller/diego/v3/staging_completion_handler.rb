require 'cloud_controller/diego/staging_completion_handler_base'

module VCAP::CloudController
  module Diego
    module V3
      class StagingCompletionHandler < VCAP::CloudController::Diego::StagingCompletionHandlerBase
        attr_reader :droplet

        def initialize(droplet)
          @droplet = droplet
          @logger = Steno.logger('cc.stager')
          @logger_prefix = 'diego.staging.v3.'
        end

        def staging_complete(payload)
          logger.info(@logger_prefix + 'finished', response: payload)

          if payload[:error]
            handle_failure(payload)
          else
            handle_success(payload)
          end
        end

        def self.success_parser
          @staging_response_schema ||= Membrane::SchemaParser.parse(&schema)
        end

        private

        def handle_failure(payload)
          begin
            error_parser.validate(payload)
          rescue Membrane::SchemaValidationError => e
            logger.error(@logger_prefix + 'failure.invalid-message', staging_guid: droplet.guid, payload: payload, error: e.to_s)

            payload[:error] = { message: 'Malformed message from Diego stager', id: DEFAULT_STAGING_ERROR }
            handle_failure(payload)

            raise CloudController::Errors::ApiError.new_from_details('InvalidRequest', payload)
          end

          begin
            droplet.class.db.transaction do
              droplet.lock!

              droplet.state = DropletModel::FAILED_STATE
              droplet.error = "#{payload[:error][:id]} - #{payload[:error][:message]}"
              droplet.save_changes(raise_on_save_failure: true)
            end
          rescue => e
            logger.error(@logger_prefix + 'saving-staging-result-failed', staging_guid: droplet.guid, response: payload, error: e.message)
          end

          Loggregator.emit_error(droplet.guid, "Failed to stage droplet: #{payload[:error][:message]}")
        end

        def handle_success(payload)
          begin
            payload[:result][:process_types] ||= {} if payload[:result]
            self.class.success_parser.validate(payload)
          rescue Membrane::SchemaValidationError => e
            logger.error(@logger_prefix + 'success.invalid-message', staging_guid: droplet.guid, payload: payload, error: e.to_s)

            payload[:error] = { message: 'Malformed message from Diego stager', id: DEFAULT_STAGING_ERROR }
            handle_failure(payload)

            raise CloudController::Errors::ApiError.new_from_details('InvalidRequest', payload)
          end

          if payload[:result][:process_types].blank?
            payload[:error] = { message: 'No process types returned from stager', id: DEFAULT_STAGING_ERROR }
            handle_failure(payload)
          else
            begin
              save_staging_result(payload)
            rescue => e
              logger.error(@logger_prefix + 'saving-staging-result-failed', staging_guid: droplet.guid, response: payload, error: e.message)
            end
          end
        end
      end
    end
  end
end
