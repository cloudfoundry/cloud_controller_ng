require 'cloud_controller/blobstore/url_generator/url_generator_helpers'

module CloudController
  module Blobstore
    class UploadUrlGenerator
      include UrlGeneratorHelpers

      def initialize(blobstore_options)
        @blobstore_options = blobstore_options
      end

      def droplet_upload_url(droplet_guid)
        if @blobstore_options[:mtls]
          https_no_auth_uri("/internal/v4/droplets/#{droplet_guid}/upload")
        else
          http_droplet_upload_url(droplet_guid)
        end
      end

      def buildpack_cache_upload_url(app_guid, stack)
        if @blobstore_options[:mtls]
          https_no_auth_uri("/internal/v4/buildpack_cache/#{stack}/#{app_guid}/upload")
        else
          http_buildpack_cache_upload_url(app_guid, stack)
        end
      end

      def http_droplet_upload_url(droplet_guid)
        http_basic_auth_uri("/staging/v3/droplets/#{droplet_guid}/upload")
      end

      def http_buildpack_cache_upload_url(app_guid, stack)
        http_basic_auth_uri("/staging/v3/buildpack_cache/#{stack}/#{app_guid}/upload")
      end
    end
  end
end
