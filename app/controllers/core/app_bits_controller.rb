require "cloud_controller/upload_handler"
require "workers/runtime/app_bits_packer"

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

      raise Errors::AppBitsUploadInvalid, "missing :resources" unless params["resources"]

      fingerprints_already_in_blobstore = FingerprintsCollection.new(json_param("resources"))
      uploaded_zip_of_files_not_in_blobstore = UploadHandler.new(config).uploaded_file(params, "application")
      package_blob_store = BlobStore.new(Settings.resource_pool.fog_connection, Settings.resource_pool.resource_directory_key || "cc-resources")
      app_bit_cache = BlobStore.new(Settings.packages.fog_connection, Settings.packages.app_package_directory_key || "cc-app-packages")

      app_bits_packer = AppBitsPacker.new(package_blob_store, app_bit_cache)
      app_bits_packer.perform(app, uploaded_zip_of_files_not_in_blobstore, fingerprints_already_in_blobstore)

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

      if AppPackage.blob_store.local?
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
