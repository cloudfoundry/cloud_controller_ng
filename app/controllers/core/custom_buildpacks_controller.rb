module VCAP::CloudController
  rest_controller :CustomBuildpacks do
    disable_default_routes

    attr_reader :blob_store

    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute :name, String
      attribute :url,  String
    end

    def create
      #config[:nginx][:use_nginx] = false
      upload_handler = UploadHandler.new(config)
      file = upload_handler.uploaded_file(params, "custom_buildpacks")

      fog_connection =  { provider: "Local", local_root: "/tmp"}
      @blob_store = VCAP::CloudController::BlobStore.new(fog_connection, "cc-custom-buildpacks")
      blob_store.files.create(
          :key => params["name"],
          :body => file,
          :public => blob_store.local?
      )

      logger.debug "uploaded file: #{file}"
      logger.debug "blobstore file: #{blob_store.files.head(params["name"])}"

      return [HTTP::OK, Yajl::Encoder.encode({success: true})] if user.admin?
      [HTTP::UNAUTHORIZED, Yajl::Encoder.encode({message: "not authorized"})]
    end

    post path, :create
  end
end