module VCAP::CloudController
  rest_controller :CustomBuildpacks do
    model_class_name :Buildpack

    define_attributes do
      attribute :name, String
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

    def create
      # multipart request so the body does not contain JSON
      @request_attrs = {
        name: params['name'],
        key: "#{params['name']}#{compute_file_extension}",
        priority: params.fetch('priority', self.class.attributes[:priority].default)
      }

      logger.debug "cc.create", :model => self.class.model_class_name,
        :attributes => request_attrs

      raise InvalidRequest unless request_attrs

      before_create

      obj = nil
      model.db.transaction do
        obj = model.create_from_hash(request_attrs)
        validate_access(:create, obj, user, roles)
      end

      after_create(obj)

      [ HTTP::CREATED,
        { "Location" => "#{self.class.path}/#{obj.guid}" },
        serialization.render_json(self.class, obj, @opts)
      ]
    end

    def after_create(obj)
      file_struct = upload_handler.uploaded_file(params, "custom_buildpacks")
      File.open(file_struct.path) do |file|
        buildpack_blobstore.files.create(
            :key => request_attrs[:key],
            :body => file,
            :public => buildpack_blobstore.local?
        )
      end

      logger.debug "uploaded file: #{file_struct}"
      logger.debug "blobstore file: #{buildpack_blobstore.files.head(request_attrs[:key])}"
      logger.debug "db record: #{model.find(key: params["custom_buildpacks_name"])}"
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

    def get_buildpack_bits(guid)
      buildpack = find_guid_and_validate_access(:read_bits, guid)
      if @buildpack_blobstore.local?
        f = buildpack_blobstore.files.head(buildpack.key)
        raise self.class.not_found_exception.new(guid) unless f
        # hack to get the local path to the file
        return send_file f.send(:path)
      else
        bits_uri = "#{bits_uri(buildpack.key)}"
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

    def compute_file_extension
      params["custom_buildpacks_name"].end_with?('.tar.gz') ? '.tar.gz' : File.extname(params["custom_buildpacks_name"])
    end

    def self.not_found_exception_name
      "NotFound"
    end

    get "#{path}/:guid/bits", :get_buildpack_bits
  end
end
