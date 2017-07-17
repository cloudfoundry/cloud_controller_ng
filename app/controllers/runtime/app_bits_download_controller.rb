module VCAP::CloudController
  class AppBitsDownloadController < RestController::ModelController
    def self.dependencies
      [:package_blobstore, :missing_blob_handler]
    end

    path_base 'apps'
    model_class_name :ProcessModel
    self.not_found_exception_name = 'AppNotFound'

    get "#{path_guid}/download", :download

    def download(guid)
      process = find_guid_and_validate_access(:read, guid)
      blob_dispatcher.send_or_redirect(guid: process.latest_package.guid)
    rescue CloudController::Errors::BlobNotFound
      Loggregator.emit_error(guid, "Could not find package for #{guid}")
      logger.error "could not find package for #{guid}"
      raise CloudController::Errors::ApiError.new_from_details('AppPackageNotFound', guid)
    end

    private

    def inject_dependencies(dependencies)
      @blobstore = dependencies.fetch(:package_blobstore)
    end

    def blob_dispatcher
      BlobDispatcher.new(blobstore: @blobstore, controller: self)
    end
  end
end
