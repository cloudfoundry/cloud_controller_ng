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

            if app.present?
              if payload["task_id"] == app.staging_task_id
                if payload["error"]
                  app.mark_as_failed_to_stage # app.save is called in mark_as_failed_to_stage
                  Loggregator.emit_error(app.guid, "Failed to stage Docker application: #{payload["error"]}")
                else
                  app.mark_as_staged
                  app.save
                  @backends.find_one_to_run(app).start
                end
              else
                logger.info(
                  "diego.docker.staging.not-current",
                  :response => payload,
                  :current => app.staging_task_id,
                )
              end
            else
              logger.info(
                "diego.docker.staging.unknown-app",
                :response => payload,
              )
            end
          end
        end

        private

        def logger
          @logger ||= Steno.logger("cc.docker.stager")
        end
      end
    end
  end
end
