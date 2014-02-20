module VCAP::CloudController
  class BuildpacksController < RestController::ModelController
    define_attributes do
      attribute :name, String
      attribute :position, Integer, default: 0
      attribute :enabled, Message::Boolean, default: true
      attribute :locked, Message::Boolean, default: false
    end

    query_parameters :name

    def self.translate_validation_exception(e, attributes)
      buildpack_errors = e.errors.on(:name)
      if buildpack_errors && buildpack_errors.include?(:unique)
        Errors::BuildpackNameTaken.new("#{attributes["name"]}")
      else
        Errors::BuildpackInvalid.new(e.errors.full_messages)
      end
    end

    def delete(guid)
      buildpack = find_guid_and_validate_access(:delete, guid)
      response = do_delete(buildpack)
      delete_buildpack_in_blobstore(buildpack.key)
      response
    end

    def update(guid)
      obj = find_for_update(guid)
      model.update(obj, @request_attrs)
      [HTTP::CREATED, object_renderer.render_json(self.class, obj, @opts)]
    end

    private

    attr_reader :buildpack_blobstore

    def delete_buildpack_in_blobstore(blobstore_key)
      return unless blobstore_key
      blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(blobstore_key, :buildpack_blobstore)
      Jobs::Enqueuer.new(blobstore_delete, queue: "cc-generic").enqueue()
    end

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
