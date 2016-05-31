require 'cloud_controller/diego/staging_completion_handler_base'

module VCAP::CloudController
  module Diego
    module Buildpack
      class StagingCompletionHandler < VCAP::CloudController::Diego::StagingCompletionHandlerBase
        def initialize(runners=CloudController::DependencyLocator.instance.runners)
          super(runners, Steno.logger('cc.stager'), 'diego.staging.')
        end

        def self.success_parser
          @staging_response_schema ||= Membrane::SchemaParser.parse do
            {
              result: {
                execution_metadata: String,
                lifecycle_type:     Lifecycles::BUILDPACK,
                lifecycle_metadata: {
                  buildpack_key:      String,
                  detected_buildpack: String,
                },
                process_types: dict(Symbol, String)
              }
            }
          end
        end

        private

        def save_staging_result(app, payload)
          result = payload[:result]
          lifecycle_data = result[:lifecycle_metadata]

          app.class.db.transaction do
            app.lock!
            app.mark_as_staged
            app.update_detected_buildpack(lifecycle_data[:detected_buildpack], lifecycle_data[:buildpack_key])

            droplet = app.current_droplet
            droplet.lock!
            droplet.update_execution_metadata(result[:execution_metadata])
            if result[:process_types][:web]
              droplet.update_detected_start_command(result[:process_types][:web])
            end

            app.save_changes(raise_on_save_failure: true)
          end
        end

        def handle_success(staging_guid, payload)
          process = get_process(staging_guid)
          return if process.nil?

          begin
            if payload[:result]
              payload[:result][:process_types] ||= {}
            end

            self.class.success_parser.validate(payload)
          rescue Membrane::SchemaValidationError => e
            logger.error('diego.staging.success.invalid-message', staging_guid: staging_guid, payload: payload, error: e.to_s)
            Loggregator.emit_error(process.guid, 'Malformed message from Diego stager')

            raise CloudController::Errors::ApiError.new_from_details('InvalidRequest', payload)
          end

          begin
            save_staging_result(process, payload)
            @runners.runner_for_app(process).start
          rescue => e
            logger.error(@logger_prefix + 'saving-staging-result-failed', staging_guid: staging_guid, response: payload, error: e.message)
          end
        end
      end
    end
  end
end
