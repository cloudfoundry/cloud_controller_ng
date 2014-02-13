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
      buildpack = find_guid_and_validate_access(:read_bits, guid)
      raise Errors::BuildpackLocked if buildpack.locked?

      uploaded_file = upload_handler.uploaded_file(params, "buildpack")
      uploaded_filename = upload_handler.uploaded_filename(params, "buildpack")

      logger.info uploaded_file
      logger.info uploaded_filename
      logger.info buildpack

      raise Errors::BuildpackBitsUploadInvalid, "a filename must be specified" if uploaded_filename.to_s == ""
      raise Errors::BuildpackBitsUploadInvalid, "only zip files allowed" unless File.extname(uploaded_filename) == ".zip"
      raise Errors::BuildpackBitsUploadInvalid, "a file must be provided" if uploaded_file.to_s == ""

      sha1 = File.new(uploaded_file).hexdigest
      uploaded_filename = File.basename(uploaded_filename)

      if upload_bits(buildpack, sha1, uploaded_file, uploaded_filename)
        [HTTP::CREATED, object_renderer.render_json(self.class, buildpack, @opts)]
      else
         [HTTP::CONFLICT, nil]
      end
    ensure
      FileUtils.rm_f(uploaded_file) if uploaded_file
    end

    def upload_bits(buildpack, new_key, bits_file, new_filename)
      return false if !new_bits?(buildpack, new_key) && !new_filename?(buildpack, new_filename)

      # replace blob if new
      if new_bits?(buildpack, new_key)
        buildpack_blobstore.cp_to_blobstore(bits_file, new_key)
        old_buildpack_key = buildpack.key
      end

      model.db.transaction(savepoint: true) do
        buildpack.lock!
        buildpack.update_from_hash(key: new_key, filename: new_filename)
      end

      buildpack_blobstore.delete(old_buildpack_key) if old_buildpack_key
      return true
    end

    get "#{path_guid}/download", :download
    def download(guid)
      obj = Buildpack.find(guid: guid)
      if @buildpack_blobstore.local?
        f = buildpack_blobstore.file(obj.key)
        raise self.class.not_found_exception.new(guid) unless f
        # hack to get the local path to the file
        return send_file f.send(:path)
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
      f = buildpack_blobstore.file(key)
      return nil unless f

      # unfortunately fog doesn't have a unified interface for non-public
      # urls
      if f.respond_to?(:url)
        f.url(Time.now + 3600)
      else
        f.public_url
      end
    end

    def new_bits?(buildpack, sha)
      return buildpack.key != sha
    end

    def new_filename?(buildpack, filename)
      return buildpack.filename != filename
    end
  end
end
