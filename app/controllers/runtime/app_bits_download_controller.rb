module VCAP::CloudController
  class AppBitsDownloadController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get "#{path_guid}/download", :download
    def download(guid)
      find_guid_and_validate_access(:read, guid)

      blob = @blobstore.blob(guid)

      if blob.nil?
        Loggregator.emit_error(guid, "Could not find package for #{guid}")
        logger.error "could not find package for #{guid}"
        raise Errors::ApiError.new_from_details("AppPackageNotFound", guid)
      end

      if @blobstore.local?
        @blob_sender.send_blob(guid, "AppPackage", blob, self)
      else
        return [HTTP::FOUND, {"Location" => blob.download_url}, nil]
      end
    end

    private
    def inject_dependencies(dependencies)
      @blob_sender = dependencies.fetch(:blob_sender)
      @blobstore = dependencies.fetch(:package_blobstore)
    end
  end
end
