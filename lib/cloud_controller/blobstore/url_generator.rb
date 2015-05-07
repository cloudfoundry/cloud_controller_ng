module CloudController
  module Blobstore
    class UrlGenerator
      def initialize(blobstore_options, package_blobstore, buildpack_cache_blobstore, admin_buildpack_blobstore, droplet_blobstore)
        @blobstore_options = blobstore_options
        @package_blobstore = package_blobstore
        @buildpack_cache_blobstore = buildpack_cache_blobstore
        @admin_buildpack_blobstore = admin_buildpack_blobstore
        @droplet_blobstore = droplet_blobstore
      end

      # Downloads
      def app_package_download_url(app)
        generate_download_url(@package_blobstore, "/staging/apps/#{app.guid}", app.guid)
      end

      def package_download_url(package)
        generate_download_url(@package_blobstore, "/staging/packages/#{package.guid}", package.guid)
      end

      def buildpack_cache_download_url(app)
        generate_download_url(@buildpack_cache_blobstore, "/staging/buildpack_cache/#{app.guid}/download", "#{app.stack.name}-#{app.guid}")
      end

      def v3_app_buildpack_cache_download_url(app_guid, stack)
        generate_download_url(@buildpack_cache_blobstore, "/staging/v3/buildpack_cache/#{stack}/#{app_guid}/download", "#{stack}-#{app_guid}")
      end

      def admin_buildpack_download_url(buildpack)
        generate_download_url(@admin_buildpack_blobstore, "/v2/buildpacks/#{buildpack.guid}/download", buildpack.key)
      end

      def droplet_download_url(app)
        droplet = app.current_droplet
        return nil unless droplet

        blob = droplet.blob
        url = blob.download_url if blob

        return nil unless url
        @droplet_blobstore.local? ? staging_uri("/staging/droplets/#{app.guid}/download") : url
      end

      def v3_droplet_download_url(droplet)
        generate_download_url(@droplet_blobstore, "/staging/v3/droplets/#{droplet.guid}/download", droplet.blobstore_key)
      end

      def perma_droplet_download_url(app_guid)
        staging_uri("/staging/droplets/#{app_guid}/download")
      end

      # Uploads
      def droplet_upload_url(app)
        staging_uri("/staging/droplets/#{app.guid}/upload")
      end

      def package_droplet_upload_url(droplet_guid)
        staging_uri("/staging/v3/droplets/#{droplet_guid}/upload")
      end

      def v3_app_buildpack_cache_upload_url(app_guid, stack)
        staging_uri("/staging/v3/buildpack_cache/#{stack}/#{app_guid}/upload")
      end

      def buildpack_cache_upload_url(app)
        staging_uri("/staging/buildpack_cache/#{app.guid}/upload")
      end

      private

      def generate_download_url(store, path, blobstore_key)
        uri = store.download_uri(blobstore_key)
        return nil unless uri
        store.local? ? staging_uri(path) : uri
      end

      def staging_uri(path)
        return nil unless path

        URI::HTTP.build(
          host: @blobstore_options[:blobstore_host],
          port: @blobstore_options[:blobstore_port],
          userinfo: [@blobstore_options[:user], @blobstore_options[:password]],
          path: path,
        ).to_s
      end
    end
  end
end
