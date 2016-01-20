require 'cloud_controller/blobstore/url_generator/url_generator_helpers'

module CloudController
  module Blobstore
    class UploadUrlGenerator
      include UrlGeneratorHelpers

      def initialize(blobstore_options)
        @blobstore_options = blobstore_options
      end

      def droplet_upload_url(app)
        basic_auth_uri("/staging/droplets/#{app.guid}/upload")
      end

      def package_droplet_upload_url(droplet_guid)
        basic_auth_uri("/staging/v3/droplets/#{droplet_guid}/upload")
      end

      def v3_app_buildpack_cache_upload_url(app_guid, stack)
        basic_auth_uri("/staging/v3/buildpack_cache/#{stack}/#{app_guid}/upload")
      end

      def buildpack_cache_upload_url(app)
        basic_auth_uri("/staging/buildpack_cache/#{app.guid}/upload")
      end
    end
  end
end
