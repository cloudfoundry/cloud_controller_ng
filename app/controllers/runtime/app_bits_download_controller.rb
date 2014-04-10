module VCAP::CloudController
  class AppBitsDownloadController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get "#{path_guid}/download", :download
    def download(guid)
      find_guid_and_validate_access(:read, guid)
      blobstore = CloudController::DependencyLocator.instance.package_blobstore
      package_uri = blobstore.download_uri(guid)

      logger.debug "guid: #{guid} package_uri: #{package_uri}"

      if package_uri.nil?
        Loggregator.emit_error(guid, "Could not find package for #{guid}")
        logger.error "could not find package for #{guid}"
        raise Errors::ApiError.new_from_details("AppPackageNotFound", guid)
      end

      if blobstore.local?
        if config[:nginx][:use_nginx]
          return [HTTP::OK, { "X-Accel-Redirect" => "#{package_uri}" }, ""]
        else
          return send_file package_path, :filename => File.basename("#{path}.zip")
        end
      else
        return [HTTP::FOUND, {"Location" => package_uri}, nil]
      end
    end
  end
end
