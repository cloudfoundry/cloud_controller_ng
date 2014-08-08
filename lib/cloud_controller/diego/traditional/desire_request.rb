require "cloud_controller/diego/environment"

module VCAP::CloudController
  module Diego
    module Traditional
      class DesireRequest
        def initialize(app, blobstore_url_generator)
          @app = app
          @blobstore_url_generator = blobstore_url_generator
        end

        def as_json(_={})
          request = {
            "process_guid" => @app.versioned_guid,
            "memory_mb" => @app.memory,
            "disk_mb" => @app.disk_quota,
            "file_descriptors" => @app.file_descriptors,
            "droplet_uri" => @blobstore_url_generator.perma_droplet_download_url(@app.guid),
            "stack" => @app.stack.name,
            "start_command" => @app.detected_start_command,
            "environment" => Environment.new(@app).as_json,
            "num_instances" => @app.desired_instances,
            "routes" => @app.uris,
            "log_guid" => @app.guid,
          }

          request["health_check_timeout_in_seconds"] = @app.health_check_timeout if @app.health_check_timeout

          request
        end
      end
    end
  end
end
