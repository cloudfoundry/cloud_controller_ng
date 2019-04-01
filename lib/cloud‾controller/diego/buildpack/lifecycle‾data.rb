module VCAP::CloudController
  module Diego
    module Buildpack
      class LifecycleData
        attr_accessor :app_bits_download_uri, :build_artifacts_cache_download_uri
        attr_accessor :build_artifacts_cache_upload_uri, :buildpacks, :app_bits_checksum
        attr_accessor :droplet_upload_uri, :stack, :buildpack_cache_checksum

        def message
          message = {
            app_bits_download_uri:            app_bits_download_uri,
            build_artifacts_cache_upload_uri: build_artifacts_cache_upload_uri,
            droplet_upload_uri:               droplet_upload_uri,
            buildpacks:                       buildpacks,
            stack:                            stack,
            app_bits_checksum:                app_bits_checksum,
          }
          if build_artifacts_cache_download_uri
            message[:build_artifacts_cache_download_uri] = build_artifacts_cache_download_uri
          end
          if buildpack_cache_checksum
            message[:buildpack_cache_checksum] = buildpack_cache_checksum
          end

          schema.validate(message)
          message
        end

        private

        def schema
          @schema ||= Membrane::SchemaParser.parse do
            {
              app_bits_download_uri:                        String,
              optional(:build_artifacts_cache_download_uri) => String,
              optional(:buildpack_cache_checksum)           => String,
              build_artifacts_cache_upload_uri:             String,
              droplet_upload_uri:                           String,
              buildpacks:                                   Array,
              stack:                                        String,
              app_bits_checksum:                            Hash,
            }
          end
        end
      end
    end
  end
end
