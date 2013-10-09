module VCAP::CloudController
  rest_controller :Buildpacks do
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

    def after_destroy(buildpack)
      return unless buildpack.key
      file = buildpack_blobstore.file(buildpack.key)
      file.destroy if file
    end

    private

    attr_reader :buildpack_blobstore

    def inject_dependencies(dependencies)
      @buildpack_blobstore = dependencies[:buildpack_blobstore]
    end

    def self.not_found_exception_name
      "NotFound"
    end
  end
end
