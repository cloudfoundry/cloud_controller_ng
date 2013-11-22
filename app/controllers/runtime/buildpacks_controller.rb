module VCAP::CloudController
  rest_controller :Buildpacks do
    model_class_name :Buildpack

    define_attributes do
      attribute :name, String
      attribute :position, Integer, default: 0
      attribute :enabled, Message::Boolean, default: true
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
      logger.debug "cc.delete", :guid => guid

      buildpack = find_guid_and_validate_access(:delete, guid)

      raise_if_has_associations!(buildpack) if v2_api? && !recursive?

      blobstore_key = buildpack.key

      buildpack.destroy

      if blobstore_key
        blobstore_delete = BlobstoreDelete.new(blobstore_key, :buildpack_blobstore)
        Delayed::Job.enqueue(blobstore_delete, queue: "cc-generic")
      end

      [ HTTP::NO_CONTENT, nil ]
    end

    # New guy for updating
    def update(guid)
      obj = find_for_update(guid)

      attrs = @request_attrs.dup
      target_position = attrs.delete('position')
      model.db.transaction(savepoint: true) do
        obj.lock!
        obj.update_from_hash(attrs)
        obj.shift_to_position(target_position) if target_position
      end

      [HTTP::CREATED, serialization.render_json(self.class, obj, @opts)]
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
