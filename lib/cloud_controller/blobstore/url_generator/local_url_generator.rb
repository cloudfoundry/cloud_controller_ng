require 'cloud_controller/blobstore/url_generator/url_generator_helpers'

module CloudController
  module Blobstore
    class LocalUrlGenerator
      include UrlGeneratorHelpers

      def initialize(blobstore_options, package_blobstore, buildpack_cache_blobstore, admin_buildpack_blobstore, droplet_blobstore)
        @blobstore_options         = blobstore_options
        @package_blobstore         = package_blobstore
        @buildpack_cache_blobstore = buildpack_cache_blobstore
        @admin_buildpack_blobstore = admin_buildpack_blobstore
        @droplet_blobstore         = droplet_blobstore
      end

      # Downloads
      def app_package_download_url(app)
        return nil unless @package_blobstore.exists?(app.guid)

        basic_auth_uri("/staging/apps/#{app.guid}")
      end

      def package_download_url(package)
        return nil unless @package_blobstore.exists?(package.guid)

        basic_auth_uri("/staging/packages/#{package.guid}")
      end

      def buildpack_cache_download_url(app)
        return nil unless @buildpack_cache_blobstore.exists?(app.buildpack_cache_key)

        basic_auth_uri("/staging/buildpack_cache/#{app.guid}/download")
      end

      def v3_app_buildpack_cache_download_url(app_guid, stack)
        return nil unless @buildpack_cache_blobstore.exists?("#{app_guid}/#{stack}")

        basic_auth_uri("/staging/v3/buildpack_cache/#{stack}/#{app_guid}/download")
      end

      def admin_buildpack_download_url(buildpack)
        return nil unless @admin_buildpack_blobstore.exists?(buildpack.key)

        basic_auth_uri("/v2/buildpacks/#{buildpack.guid}/download")
      end

      def droplet_download_url(app)
        droplet = app.current_droplet
        return nil unless droplet
        return nil unless droplet.blob

        basic_auth_uri("/staging/droplets/#{app.guid}/download")
      end

      def v3_droplet_download_url(droplet)
        return nil unless @droplet_blobstore.exists?(droplet.blobstore_key)

        basic_auth_uri("/staging/v3/droplets/#{droplet.guid}/download")
      end
    end
  end
end
