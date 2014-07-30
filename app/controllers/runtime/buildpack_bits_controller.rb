module VCAP::CloudController
  class BuildpackBitsController < RestController::ModelController
    path_base "buildpacks"
    model_class_name :Buildpack
    allow_unauthenticated_access only: :download
    authenticate_basic_auth("#{path}/*/download") do
      [VCAP::CloudController::Config.config[:staging][:auth][:user],
       VCAP::CloudController::Config.config[:staging][:auth][:password]]
    end

    put "#{path_guid}/bits", :upload
    def upload(guid)
      buildpack = find_guid_and_validate_access(:upload, guid)
      raise Errors::ApiError.new_from_details("BuildpackLocked") if buildpack.locked?

      uploaded_file = upload_handler.uploaded_file(params, "buildpack")
      uploaded_filename = upload_handler.uploaded_filename(params, "buildpack")

      logger.info "Uploading bits for #{buildpack.name}, file: uploaded_filename"

      raise Errors::ApiError.new_from_details("BuildpackBitsUploadInvalid", "a filename must be specified") if uploaded_filename.to_s == ""
      raise Errors::ApiError.new_from_details("BuildpackBitsUploadInvalid", "only zip files allowed") unless File.extname(uploaded_filename) == ".zip"
      raise Errors::ApiError.new_from_details("BuildpackBitsUploadInvalid", "a file must be provided") if uploaded_file.to_s == ""

      uploaded_filename = File.basename(uploaded_filename)

      upload_buildpack = UploadBuildpack.new(buildpack_blobstore)

      if upload_buildpack.upload_buildpack(buildpack, uploaded_file, uploaded_filename)
        [HTTP::CREATED, object_renderer.render_json(self.class, buildpack, @opts)]
      else
         [HTTP::NO_CONTENT, nil]
      end
    ensure
      FileUtils.rm_f(uploaded_file) if uploaded_file
    end

    get "#{path_guid}/download", :download
    def download(guid)
      obj = Buildpack.find(guid: guid)
      if @buildpack_blobstore.local?
        blob = buildpack_blobstore.blob(obj.key)
        raise self.class.not_found_exception.new(guid) unless blob
        return send_file blob.local_path
      else
        bits_uri = "#{bits_uri(obj.key)}"
        return [HTTP::FOUND, {"Location" => bits_uri}, nil]
      end
    end

    private

    attr_reader :buildpack_blobstore, :upload_handler

    def inject_dependencies(dependencies)
      super
      @buildpack_blobstore = dependencies[:buildpack_blobstore]
      @upload_handler = dependencies[:upload_handler]
    end

    def bits_uri(key)
      blob = buildpack_blobstore.blob(key)
      return nil unless blob
      blob.download_url
    end
  end
end
