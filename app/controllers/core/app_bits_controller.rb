require "cloud_controller/upload_handler"

module VCAP::CloudController
  rest_controller :AppBits do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      full Permissions::CFAdmin
      full Permissions::SpaceDeveloper
    end

    def upload(guid)
      app = find_guid_and_validate_access(:update, guid)

      unless params["resources"]
        raise Errors::AppBitsUploadInvalid.new("missing :resources")
      end

      fingerprints_already_in_blobstore = json_param("resources")
      unless fingerprints_already_in_blobstore.kind_of?(Array)
        raise Errors::AppBitsUploadInvalid.new("invalid :resources")
      end

      # TODO: validate upload path
      upload_handler = UploadHandler.new(config)
      uploaded_zip_of_files_not_in_blobstore = upload_handler.uploaded_file(params, "application")

      sha1 = AppPackage.to_zip(app.guid, fingerprints_already_in_blobstore, uploaded_zip_of_files_not_in_blobstore)
      app.package_hash = sha1
      app.save

      HTTP::CREATED
    rescue VCAP::CloudController::Errors::AppBitsUploadInvalid, VCAP::CloudController::Errors::AppPackageInvalid
      app.mark_as_failed_to_stage
      raise
    end

    def download(guid)
      find_guid_and_validate_access(:read, guid)

      package_uri = AppPackage.package_uri(guid)
      logger.debug "guid: #{guid} package_uri: #{package_uri}"

      if package_uri.nil?
        logger.error "could not find package for #{guid}"
        raise Errors::AppPackageNotFound.new(guid)
      end

      if AppPackage.local?
        if config[:nginx][:use_nginx]
          return [200, { "X-Accel-Redirect" => "#{package_uri}" }, ""]
        else
          return send_file package_path, :filename => File.basename("#{path}.zip")
        end
      else
        return [HTTP::FOUND, {"Location" => package_uri}, nil]
      end
    end

    def json_param(name)
      raw = params[name]
      Yajl::Parser.parse(raw)
    rescue Yajl::ParseError
      raise Errors::AppBitsUploadInvalid.new("invalid :#{name}")
    end

    put "#{path_guid}/bits", :upload
    get "#{path_guid}/download", :download
  end
end
