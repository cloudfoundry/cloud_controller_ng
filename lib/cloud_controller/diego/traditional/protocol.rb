require "cloud_controller/diego/traditional/buildpack_entry_generator"
require "cloud_controller/diego/environment"

module VCAP::CloudController
  module Diego
    module Traditional
      class Protocol
        def initialize(blobstore_url_generator)
          @blobstore_url_generator = blobstore_url_generator
          @buildpack_entry_generator = BuildpackEntryGenerator.new(@blobstore_url_generator)
        end

        def stage_app_request(app)
          ["diego.staging.start", stage_app_message(app).to_json]
        end

        def desire_app_request(app)
          ["diego.desire.app", desire_app_message(app).to_json]
        end

        def stage_app_message(app)
          {
            "app_id" => app.guid,
            "task_id" => app.staging_task_id,
            "memory_mb" => app.memory,
            "disk_mb" => app.disk_quota,
            "file_descriptors" => app.file_descriptors,
            "environment" => Environment.new(app).as_json,
            "stack" => app.stack.name,
            "build_artifacts_cache_download_uri" => @blobstore_url_generator.buildpack_cache_download_url(app),
            "app_bits_download_uri" => @blobstore_url_generator.app_package_download_url(app),
            "buildpacks" => @buildpack_entry_generator.buildpack_entries(app)
          }
        end

        def desire_app_message(app)
          message = {
            "process_guid" => app.versioned_guid,
            "memory_mb" => app.memory,
            "disk_mb" => app.disk_quota,
            "file_descriptors" => app.file_descriptors,
            "droplet_uri" => @blobstore_url_generator.perma_droplet_download_url(app.guid),
            "stack" => app.stack.name,
            "start_command" => app.detected_start_command,
            "environment" => Environment.new(app).as_json,
            "num_instances" => app.desired_instances,
            "routes" => app.uris,
            "log_guid" => app.guid,
          }

          message["health_check_timeout_in_seconds"] = app.health_check_timeout if app.health_check_timeout
          message
        end
      end
    end
  end
end
