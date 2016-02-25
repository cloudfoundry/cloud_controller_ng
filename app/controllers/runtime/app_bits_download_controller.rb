module VCAP::CloudController
  class AppBitsDownloadController < RestController::ModelController
    def self.dependencies
      [:blob_sender, :package_blobstore, :missing_blob_handler]
    end

    path_base 'apps'
    model_class_name :App

    get "#{path_guid}/download", :download
    def download(guid)
      find_guid_and_validate_access(:read, guid)

      blob = @blobstore.blob(guid)

      if blob.nil?
        Loggregator.emit_error(guid, "Could not find package for #{guid}")
        logger.error "could not find package for #{guid}"
        raise Errors::ApiError.new_from_details('AppPackageNotFound', guid)
      end

      blob_dispatcher.send_or_redirect(local: @blobstore.local?, blob: blob)
    end

    private

    def inject_dependencies(dependencies)
      @blob_sender = dependencies.fetch(:blob_sender)
      @blobstore = dependencies.fetch(:package_blobstore)
    end

    def blob_dispatcher
      BlobDispatcher.new(blob_sender: @blob_sender, controller: self)
    end
  end
end
