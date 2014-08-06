module VCAP::CloudController
  module Diego
    class StagingRequest
      def initialize(app, blobstore_url_generator, buildpack_entry_generator)
        @app = app
        @blobstore_url_generator = blobstore_url_generator
        @buildpack_entry_generator = buildpack_entry_generator
      end

      def as_json(_={})
        {
          "app_id" => @app.guid,
          "task_id" => @app.staging_task_id,
          "memory_mb" => @app.memory,
          "disk_mb" => @app.disk_quota,
          "file_descriptors" => @app.file_descriptors,
          "environment" => Environment.new(@app).to_a,
          "stack" => @app.stack.name,
          "build_artifacts_cache_download_uri" => @blobstore_url_generator.buildpack_cache_download_url(@app),
          "app_bits_download_uri" => @blobstore_url_generator.app_package_download_url(@app),
          "buildpacks" => @buildpack_entry_generator.buildpack_entries(@app)
        }
      end
    end
  end
end
