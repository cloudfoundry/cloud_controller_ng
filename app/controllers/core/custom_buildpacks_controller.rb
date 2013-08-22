module VCAP::CloudController
  rest_controller :CustomBuildpacks do
    disable_default_routes
    model_class_name :Buildpack

    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute :name, String
      attribute :key,  String
    end

    def self.translate_validation_exception(e, attributes)
      buildpack_errors = e.errors.on([:name])
      if buildpack_errors && buildpack_errors.include?(:unique)
        Errors::BuildpackNameTaken.new("#{attributes["name"]}")
      else
        Errors::BuildpackNameTaken.new(e.errors.full_messages)
      end
    end


    def create
      file_struct = upload_handler.uploaded_file(params, "custom_buildpacks")
      key = "#{params['name']}#{compute_file_extension}"

      File.open(file_struct.path) do |file|
        buildpack_blobstore.files.create(
            :key => key,
            :body => file,
            :public => buildpack_blobstore.local?
        )
      end

      model.db.transaction do
        model.create_from_hash({name: params["name"], key: key})
      end

      logger.debug "uploaded file: #{file_struct}"
      logger.debug "blobstore file: #{buildpack_blobstore.files.head(params["custom_buildpacks_name"])}"
      logger.debug "db record: #{model.find(key: params["custom_buildpacks_name"])}"

      return [HTTP::OK, Yajl::Encoder.encode({success: true})] if user.admin?
      [HTTP::UNAUTHORIZED, Yajl::Encoder.encode({message: "not authorized"})]
    end

    protected

    attr_reader :buildpack_blobstore, :upload_handler

    def inject_dependencies(dependencies)
      @buildpack_blobstore = dependencies[:buildpack_blobstore]
      @upload_handler = dependencies[:upload_handler]
    end

    def read(name)
      buildpack = model.find(name: name).to_json
      [HTTP::OK, Yajl::Encoder.encode({success: true, model: buildpack})]
    end

    def get_bits(name)
      buildpack = model.find(name: name)
      if config[:nginx][:use_nginx]
        return [200, { "X-Accel-Redirect" => "#{bits_uri(buildpack.key)}" }, ""]
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

    post path, :create
    get path, :enumerate
    get "#{path}/:name", :read
    get "#{path}/:name/bits", :get_bits
  end
end