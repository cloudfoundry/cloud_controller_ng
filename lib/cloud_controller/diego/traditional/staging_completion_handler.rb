require "cloud_controller/diego/staging_completion_handler_base"

module VCAP::CloudController
  module Diego
    module Traditional
      class StagingCompletionHandler < VCAP::CloudController::Diego::StagingCompletionHandlerBase

        def initialize(runners)
          super(runners, Steno.logger("cc.stager"), "diego.staging.")
          @staging_response_schema = Membrane::SchemaParser.parse do
            {
              "app_id" => String,
              "task_id" => String,
              "buildpack_key" => String,
              "detected_buildpack" => String,
              "execution_metadata" => String,
            }
          end
        end

        private

        def handle_success(payload)
          begin
            @staging_response_schema.validate(payload)
          rescue Membrane::SchemaValidationError => e
            logger.error("diego.staging.invalid-message", payload: payload, error: e.to_s)
            raise Errors::ApiError.new_from_details("InvalidRequest", payload)
          end

          super
        end

        def save_staging_result(app, payload)
          already_staged = false

          app.class.db.transaction do
            app.lock!

            already_staged = app.staged?

            app.mark_as_staged
            app.update_detected_buildpack(payload["detected_buildpack"], payload["buildpack_key"])

            droplet = app.current_droplet
            droplet.lock!
            droplet.update_execution_metadata(payload["execution_metadata"])
            if payload.has_key?("detected_start_command")
              droplet.update_detected_start_command(payload["detected_start_command"]["web"])
            end

            app.save_changes
          end

          already_staged
        end
      end
    end
  end
end
