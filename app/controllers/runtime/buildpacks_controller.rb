module VCAP::CloudController
  class BuildpacksController < RestController::ModelController
    define_attributes do
      attribute :name, String
      attribute :position, Integer, default: 0
      attribute :enabled, Message::Boolean, default: true
      attribute :locked, Message::Boolean, default: false
    end

    query_parameters :name

    def initialize(*args)
      super
      @opts.merge!(order_by: :position)
    end

    def self.translate_validation_exception(e, attributes)
      buildpack_errors = e.errors.on(:name)
      if buildpack_errors && buildpack_errors.include?(:unique)
        Errors::ApiError.new_from_details("BuildpackNameTaken", "#{attributes["name"]}")
      else
        Errors::ApiError.new_from_details("BuildpackInvalid", e.errors.full_messages)
      end
    end

    def delete(guid)
      buildpack = find_guid_and_validate_access(:delete, guid)
      response = do_delete(buildpack)

      BuildpackBitsDelete.delete_when_safe(buildpack.key, :buildpack_blobstore, @config[:staging][:timeout_in_seconds])
      response
    end

    def update(guid)
      obj = find_for_update(guid)
      model.update(obj, @request_attrs)
      [HTTP::CREATED, object_renderer.render_json(self.class, obj, @opts)]
    end

    private

    attr_reader :buildpack_blobstore

    def inject_dependencies(dependencies)
      super
      @buildpack_blobstore = dependencies[:buildpack_blobstore]
    end

    def self.not_found_exception_name
      "NotFound"
    end

    define_messages
    define_routes
  end
end
