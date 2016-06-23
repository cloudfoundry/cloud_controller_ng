require 'cloud_controller/diego/buildpack/lifecycle_data'
require 'cloud_controller/diego/buildpack/buildpack_entry_generator'

module VCAP
  module CloudController
    module Diego
      module Buildpack
        class LifecycleProtocol
          def initialize(blobstore_url_generator)
            @blobstore_url_generator = blobstore_url_generator
            @buildpack_entry_generator = BuildpackEntryGenerator.new(@blobstore_url_generator)
          end

          def lifecycle_data(app)
            lifecycle_data = LifecycleData.new
            lifecycle_data.app_bits_download_uri = @blobstore_url_generator.app_package_download_url(app)
            lifecycle_data.build_artifacts_cache_download_uri = @blobstore_url_generator.buildpack_cache_download_url(app)
            lifecycle_data.build_artifacts_cache_upload_uri = @blobstore_url_generator.buildpack_cache_upload_url(app)
            lifecycle_data.droplet_upload_uri = @blobstore_url_generator.droplet_upload_url(app)
            lifecycle_data.buildpacks = @buildpack_entry_generator.buildpack_entries(app)
            lifecycle_data.stack = app.stack.name
            [Lifecycles::BUILDPACK, lifecycle_data.message]
          end

          def desired_app_message(app)
            {
              'start_command' => app.command.nil? ? app.detected_start_command : app.command,
              'droplet_uri' => @blobstore_url_generator.unauthorized_perma_droplet_download_url(app),
              'droplet_hash' => app.current_droplet.droplet_hash,
            }
          end
        end
      end
    end
  end
end
