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

      def admin_buildpack_download_url(buildpack)
        blob = @admin_buildpack_blobstore.blob(buildpack.key)

        message = "Missing blob for #{buildpack.name}. Specify a different buildpack with the -b flag or contact your operator."
        raise CloudController::Errors::ApiError.new_from_details('StagingError', message) unless blob

        url_for_blob(blob)
      end

      def droplet_download_url(droplet)
        return nil unless droplet
        blob = @droplet_blobstore.blob(droplet.blobstore_key)
        return nil unless blob

        url_for_blob(blob)
      end

      def buildpack_cache_download_url(app_guid, stack)
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
