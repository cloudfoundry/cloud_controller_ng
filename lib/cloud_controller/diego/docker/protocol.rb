module VCAP::CloudController
  module Diego
    module Docker
      class Protocol
        def stage_app_request(app)
          ["diego.docker.staging.start", stage_app_message(app).to_json]
        end

        def stage_app_message(app)
          {
            "app_id" => app.guid,
            "task_id" => app.staging_task_id,
            "memory_mb" => app.memory,
            "disk_mb" => app.disk_quota,
            "file_descriptors" => app.file_descriptors,
            "stack" => app.stack.name,
            "docker_image" => app.docker_image,
          }
        end

        def desire_app_request(app)
          raise NotImplemented, "https://www.pivotaltracker.com/story/show/75217152"
        end

        def desire_app_message(app)
          raise NotImplemented, "https://www.pivotaltracker.com/story/show/75217152"
        end
      end
    end
  end
end
