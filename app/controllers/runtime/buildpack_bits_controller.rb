module VCAP::CloudController
  class BuildpackBitsController < RestController::ModelController
    def self.dependencies
      [:buildpack_blobstore, :upload_handler]
    end

    path_base 'buildpacks'
    model_class_name :Buildpack
    allow_unauthenticated_access only: :download
    authenticate_basic_auth("#{path}/*/download") do
      [VCAP::CloudController::Config.config.get(:staging, :auth, :user),
       VCAP::CloudController::Config.config.get(:staging, :auth, :password)]
    end

    put "#{path_guid}/bits", :upload
    def upload(guid)
      buildpack = find_guid_and_validate_access(:upload, guid)
      raise CloudController::Errors::ApiError.new_from_details('BuildpackLocked') if buildpack.locked?

      uploaded_file = upload_handler.uploaded_file(request.POST, 'buildpack')
      uploaded_filename = upload_handler.uploaded_filename(request.POST, 'buildpack')

      logger.info "Uploading bits for #{buildpack.name}, file: uploaded_filename"

      raise CloudController::Errors::ApiError.new_from_details('BuildpackBitsUploadInvalid', 'a filename must be specified') if uploaded_filename.to_s == ''
      raise CloudController::Errors::ApiError.new_from_details('BuildpackBitsUploadInvalid', 'only zip files allowed') unless File.extname(uploaded_filename) == '.zip'
      raise CloudController::Errors::ApiError.new_from_details('BuildpackBitsUploadInvalid', 'a file must be provided') if uploaded_file.to_s == ''

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
      blob_dispatcher.send_or_redirect(guid: obj.key)
    rescue CloudController::Errors::BlobNotFound
      raise CloudController::Errors::ApiError.new_from_details('NotFound', guid)
    end

    private

    attr_reader :buildpack_blobstore, :upload_handler

    def blob_dispatcher
      BlobDispatcher.new(blobstore: buildpack_blobstore, controller: self)
    end

    def inject_dependencies(dependencies)
      super
      @buildpack_blobstore = dependencies[:buildpack_blobstore]
      @upload_handler = dependencies[:upload_handler]
    end
  end
end
