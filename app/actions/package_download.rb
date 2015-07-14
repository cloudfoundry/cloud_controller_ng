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
        return nil, blob.download_url
      end
    end

    private

    def logger
      @logger ||= Steno.logger('cc.action.package_upload')
    end
  end
end
