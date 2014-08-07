module VCAP::CloudController
  module Diego
    module Docker
      class Client
        def initialize(message_bus)
          @message_bus = message_bus
        end

        def send_stage_request(app)
          logger.info("staging.begin", app_guid: app.guid)

          app.update(staging_task_id: VCAP.secure_uuid)

          @message_bus.publish("diego.docker.staging.start", {
            "app_id" => app.guid,
            "task_id" => app.staging_task_id,
            "memory_mb" => app.memory,
            "disk_mb" => app.disk_quota,
            "file_descriptors" => app.file_descriptors,
            "stack" => app.stack.name,
            "docker_image" => app.docker_image,
          })
        end

        private

        def logger
          @logger ||= Steno.logger("cc.diego.docker.client")
        end
      end
    end
  end
end
