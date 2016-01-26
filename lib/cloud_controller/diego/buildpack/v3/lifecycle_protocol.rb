module VCAP
  module CloudController
    module Diego
      module Buildpack
        module V3
          class LifecycleProtocol
            def initialize(blobstore_url_generator)
              @blobstore_url_generator   = blobstore_url_generator
              @buildpack_entry_generator = BuildpackEntryGenerator.new(@blobstore_url_generator)
            end

            def lifecycle_data(package, staging_details)
              lifecycle_data = LifecycleData.new
              lifecycle_data.app_bits_download_uri = @blobstore_url_generator.package_download_url(package)
              lifecycle_data.build_artifacts_cache_download_uri = @blobstore_url_generator.v3_app_buildpack_cache_download_url(
                package.app_guid, staging_details.lifecycle.staging_stack)
              lifecycle_data.build_artifacts_cache_upload_uri = @blobstore_url_generator.v3_app_buildpack_cache_upload_url(
                package.app_guid, staging_details.lifecycle.staging_stack)
              lifecycle_data.droplet_upload_uri = @blobstore_url_generator.package_droplet_upload_url(staging_details.droplet.guid)
              lifecycle_data.buildpacks = @buildpack_entry_generator.buildpack_entries(staging_details.lifecycle.buildpack_info)
              lifecycle_data.stack = staging_details.lifecycle.staging_stack
              [Lifecycles::BUILDPACK, lifecycle_data.message]
            end
          end
        end
      end
    end
  end
end
