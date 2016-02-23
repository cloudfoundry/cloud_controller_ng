module VCAP::CloudController
  class PackageDownload
    class InvalidPackage < StandardError; end

    def download(package)
      logger.info("fetching bits download URL for package #{package.guid}")

      blobstore = CloudController::DependencyLocator.instance.package_blobstore

      blob = blobstore.blob(package.guid)

      if blobstore.local?
        return blob.local_path, nil
      else
        begin
          return nil, blob.public_download_url
        rescue CloudController::Blobstore::SigningRequestError => e
          logger.error("failed to get download url: #{e.message}")
          return nil
        end
      end
    end

    private

    def logger
      @logger ||= Steno.logger('cc.action.package_download')
    end
  end
end
