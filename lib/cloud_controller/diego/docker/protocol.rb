require "cloud_controller/diego/environment"

module VCAP::CloudController
  module Diego
    module Docker
      class Protocol
        def initialize(staging_timeout)
          @staging_timeout = staging_timeout
        end

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
            "timeout" => @staging_timeout,
          }
        end

        def desire_app_request(app)
          ["diego.docker.desire.app", desire_app_message(app).to_json]
        end

        def stop_staging_app_request(app, task_id)
          ["diego.docker.staging.stop", stop_staging_message(app, task_id).to_json]
        end

        def desire_app_message(app)
          message = {
            "process_guid" => app.versioned_guid,
            "memory_mb" => app.memory,
            "disk_mb" => app.disk_quota,
            "file_descriptors" => app.file_descriptors,
            "stack" => app.stack.name,
            "start_command" => app.command,
            "execution_metadata" => app.execution_metadata,
            "environment" => Environment.new(app).as_json,
            "num_instances" => app.desired_instances,
            "routes" => app.uris,
            "log_guid" => app.guid,
            "docker_image" => app.docker_image,
          }

          message["health_check_timeout_in_seconds"] = app.health_check_timeout if app.health_check_timeout
          message
        end

        def stop_staging_message(app, task_id)
          {
            "app_id" => app.guid,
            "task_id" => task_id,
          }
        end
      end
    end
  end
end
