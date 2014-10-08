module VCAP::CloudController
  module Diego
    module Traditional
      class StagingCompletionHandler

        def initialize(backends)
          @backends = backends
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

        def staging_complete(payload)
          logger.info("diego.staging.finished", :response => payload)

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
          begin
            @staging_response_schema.validate(payload)
          rescue Membrane::SchemaValidationError => e
            logger.error("diego.staging.invalid-message", payload: payload, error: e.to_s)
            raise Errors::ApiError.new_from_details("InvalidRequest", payload)
          end

          app = get_app(payload)
          return if app.nil?

          save_staging_result(app, payload)
          @backends.find_one_to_run(app).start
        end

        def get_app(payload)
          app = App.find(guid: payload["app_id"])
          if app == nil
            logger.error("diego.staging.unknown-app", :response => payload)
            return
          end

          return app if staging_is_current(app, payload)
          nil
        end

        def staging_is_current(app, payload)
          if payload["task_id"] != app.staging_task_id
            logger.warn(
              "diego.staging.not-current",
              :response => payload,
              :current => app.staging_task_id)
            return false
          end

          return true
        end

        def save_staging_result(app, payload)
          app.class.db.transaction do
            app.lock!
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
        end

        def logger
          @logger ||= Steno.logger("cc.stager")
        end
      end
    end
  end
end
