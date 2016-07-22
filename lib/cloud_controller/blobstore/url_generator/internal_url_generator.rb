require 'cloud_controller/blobstore/url_generator/url_generator_helpers'

module CloudController
  module Blobstore
    class InternalUrlGenerator
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
        blob = @package_blobstore.blob(app.guid)
        return nil unless blob

        url_for_blob(blob)
      end

      def buildpack_cache_download_url(app)
        blob = @buildpack_cache_blobstore.blob(app.buildpack_cache_key)
        return nil unless blob

        url_for_blob(blob)
      end

      def admin_buildpack_download_url(buildpack)
        blob = @admin_buildpack_blobstore.blob(buildpack.key)
        return nil unless blob

        url_for_blob(blob)
      end

      def droplet_download_url(app)
        droplet = app.current_droplet
        return nil unless droplet
        blob = droplet.blob
        url_for_blob(blob) if blob
      end

      # V3 downloads
      def v3_droplet_download_url(droplet)
        blob = @droplet_blobstore.blob(droplet.blobstore_key)
        return nil unless blob

        url_for_blob(blob)
      end

      def v3_app_buildpack_cache_download_url(app_guid, stack)
        blob = @buildpack_cache_blobstore.blob("#{app_guid}/#{stack}")
        return nil unless blob

        url_for_blob(blob)
      end

      def package_download_url(package)
        blob = @package_blobstore.blob(package.guid)
        return nil unless blob

        url_for_blob(blob)
      end

      private

      def url_for_blob(blob)
        blob.internal_download_url
      rescue SigningRequestError => e
        logger.error("failed to get download url: #{e.message}, backtrace: #{e.backtrace}")
        raise CloudController::Errors::ApiError.new_from_details('BlobstoreUnavailable')
      end

      def logger
        @logger ||= Steno.logger('cc.blobstore.internal_url_generator')
      end
    end
  end
end
