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

      def buildpack_cache_download_url(app)
        generate_download_url(@buildpack_cache_blobstore, "/staging/buildpack_cache/#{app.guid}/download", app.guid)
      end

      def admin_buildpack_download_url(buildpack)
        generate_download_url(@admin_buildpack_blobstore, "/v2/buildpacks/#{buildpack.guid}/download", buildpack.key)
      end

      def droplet_download_url(app)
        droplet = app.current_droplet
        return nil unless droplet

        if @droplet_blobstore.local?
          staging_uri("/staging/droplets/#{app.guid}/download")
        else
          droplet.download_url
        end
      end

      # Uploads
      def droplet_upload_url(app)
        staging_uri("/staging/droplets/#{app.guid}/upload")
      end

      def buildpack_cache_upload_url(app)
        staging_uri("/staging/buildpack_cache/#{app.guid}/upload")
      end

      private
      def generate_download_url(store, path, blobstore_key)
        if store.local?
          if store.file(blobstore_key)
            staging_uri(path)
          end
        else
          store.download_uri(blobstore_key)
        end
      end

      def staging_uri(path)
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
