require 'securerandom'

module VCAP::CloudController
  module Diego
    module Docker
      class StagingCompletionHandler
        def initialize(message_bus, backends)
          @message_bus = message_bus
          @backends = backends
        end

        def subscribe!
          @message_bus.subscribe("diego.docker.staging.finished", queue: "cc") do |payload|
            app = App.find(guid: payload["app_id"])

            unless app.present?
              logger.error(
                "diego.docker.staging.unknown-app",
                :response => payload,
              )
              return
            end

            if payload["task_id"] != app.staging_task_id
              logger.warn(
                "diego.docker.staging.not-current",
                :response => payload,
                :current => app.staging_task_id,
              )
              return
            end

            if payload["error"]
              app.mark_as_failed_to_stage # app.save is called in mark_as_failed_to_stage
              Loggregator.emit_error(app.guid, "Failed to stage Docker application: #{payload["error"]}")
            else
              save_staging_result(app, payload)
              @backends.find_one_to_run(app).start
            end
          end
        end

        private

        def save_staging_result(app, payload)
          app.class.db.transaction do
            app.lock!
            app.mark_as_staged
            app.add_new_droplet(SecureRandom.hex) # placeholder until image ID is obtained during staging

            if payload.has_key?("execution_metadata")
              droplet = app.current_droplet
              droplet.lock!
              droplet.update_execution_metadata(payload["execution_metadata"])
              if payload.has_key?("detected_start_command")
                droplet.update_detected_start_command(payload["detected_start_command"]["web"])
              end
            end

            app.save_changes
          end
        end

        def logger
          @logger ||= Steno.logger("cc.docker.stager")
        end
      end
    end
  end
end
