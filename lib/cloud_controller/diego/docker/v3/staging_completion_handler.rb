require 'securerandom'
require 'cloud_controller/diego/staging_completion_handler_base'

module VCAP::CloudController
  module Diego
    module Docker
      module V3
        class StagingCompletionHandler < VCAP::CloudController::Diego::StagingCompletionHandlerBase
          def initialize
            super(nil, Steno.logger('cc.docker.stager'), 'diego.docker.staging.v3.')
          end

          def self.success_parser
            @staging_response_schema ||= Membrane::SchemaParser.parse do
              {
                result: {
                  execution_metadata: String,
                  process_types:      dict(Symbol, String),
                  lifecycle_type:     Lifecycles::DOCKER,
                  lifecycle_metadata: {
                    docker_image: String
                  }
                }
              }
            end
          end

          private

          def save_staging_result(droplet, payload)
            droplet.class.db.transaction do
              droplet.lock!
              droplet.process_types      = payload[:result][:process_types]
              droplet.execution_metadata = payload[:result][:execution_metadata]
              droplet.mark_as_staged
              droplet.save_changes(raise_on_save_failure: true)
            end
          end

          def handle_success(droplet, payload)
            begin
              if payload[:result]
                payload[:result][:process_types] ||= {}
              end

              self.class.success_parser.validate(payload)

            rescue Membrane::SchemaValidationError => e
              logger.error(@logger_prefix + 'success.invalid-message', staging_guid: droplet.guid, payload: payload, error: e.to_s)

              payload[:error] = { message: 'Malformed message from Diego stager', id: DEFAULT_STAGING_ERROR }
              handle_failure(droplet, payload)

              raise Errors::ApiError.new_from_details('InvalidRequest', payload)
            end

            if payload[:result][:process_types] == {}
              payload[:error] = { message: 'No process types returned from stager', id: DEFAULT_STAGING_ERROR }
              handle_failure(droplet, payload)
            else
              begin
                save_staging_result(droplet, payload)
              rescue => e
                logger.error(@logger_prefix + 'saving-staging-result-failed', staging_guid: droplet.guid, response: payload, error: e.message)
              end
            end
          end

          def handle_failure(droplet, payload)
            begin
              error_parser.validate(payload)
            rescue Membrane::SchemaValidationError => e
              logger.error(@logger_prefix + 'failure.invalid-message', staging_guid: droplet.guid, payload: payload, error: e.to_s)

              payload[:error] = { message: 'Malformed message from Diego stager', id: DEFAULT_STAGING_ERROR }
              handle_failure(droplet, payload)

              raise Errors::ApiError.new_from_details('InvalidRequest', payload)
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
        end
      end
    end
  end
end
