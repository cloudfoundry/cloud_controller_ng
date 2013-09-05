module VCAP::CloudController
  rest_controller :CustomBuildpacks do
    model_class_name :Buildpack

    define_attributes do
      attribute :name, String
      attribute :key,  String, :exclude_in => [:create, :update]
      attribute :priority, Integer, :default => 0
    end

    query_parameters :name

    def self.translate_validation_exception(e, attributes)
      buildpack_errors = e.errors.on([:name])
      if buildpack_errors && buildpack_errors.include?(:unique)
        Errors::BuildpackNameTaken.new("#{attributes["name"]}")
      else
        Errors::BuildpackNameTaken.new(e.errors.full_messages)
      end
    end

    def after_destroy(obj)
      file = buildpack_blobstore.files.head(obj.key)
      file.destroy if file
    end

    protected

    attr_reader :buildpack_blobstore, :upload_handler

    def inject_dependencies(dependencies)
      @buildpack_blobstore = dependencies[:buildpack_blobstore]
      @upload_handler = dependencies[:upload_handler]
    end

    def upload_bits(guid)
      obj = find_guid_and_validate_access(:read_bits, guid)
      file_struct = upload_handler.uploaded_file(params, "buildpack")
      uploaded_filename = upload_handler.uploaded_filename(params, "buildpack")
      buildpack_key = "#{obj.name}#{compute_file_extension(uploaded_filename)}"

      model.db.transaction do
        obj.lock!
        obj.update_from_hash(key: buildpack_key)
      end

      File.open(file_struct.path) do |file|
        buildpack_blobstore.files.create(
        :key => buildpack_key,
        :body => file,
        :public => buildpack_blobstore.local?
        )
      end

      logger.debug "uploaded file: #{file_struct}"
      logger.debug "blobstore file: #{buildpack_blobstore.files.head(buildpack_key)}"
      logger.debug "db record: #{obj}"

      [HTTP::CREATED, serialization.render_json(self.class, obj, @opts)]
    end


    def download_bits(guid)
      obj = find_guid_and_validate_access(:read_bits, guid)
      if @buildpack_blobstore.local?
        f = buildpack_blobstore.files.head(obj.key)
        raise self.class.not_found_exception.new(guid) unless f
        # hack to get the local path to the file
        return send_file f.send(:path)
      else
        bits_uri = "#{bits_uri(obj.key)}"
        return [HTTP::FOUND, {"Location" => bits_uri}, nil]
      end
    end

    private

    def bits_uri(key)
      f = buildpack_blobstore.files.head(key)
      return nil unless f

      # unfortunately fog doesn't have a unified interface for non-public
      # urls
      if f.respond_to?(:url)
        f.url(Time.now + 3600)
      else
        f.public_url
      end
    end

    def compute_file_extension(filename)
      filename.end_with?('.tar.gz') ? '.tar.gz' : File.extname(filename)
    end

    def self.not_found_exception_name
      "NotFound"
    end

    post "#{path}/:guid/bits", :upload_bits
    get "#{path}/:guid/download", :download_bits
  end
end
