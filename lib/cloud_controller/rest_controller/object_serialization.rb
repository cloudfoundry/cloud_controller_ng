module VCAP::CloudController::RestController
  # Serialize objects according in the format required by the vcap
  # rest api.

  module ObjectSerialization
    PRETTY_DEFAULT = true
    MAX_INLINE_DEFAULT = 50
    INLINE_RELATIONS_DEFAULT = 0

    # Render an object to json, using export and security properties
    # set by its controller.
    #
    # @param [RestController] controller Controller for the object being
    # encoded.
    #
    # @param [Sequel::Model] obj Object to encode.
    #
    # @option opts [Boolean] :pretty Controlls pretty formating of the encoded
    # json.  Defaults to true.
    #
    # @option opts [Integer] :inline_relations_depth Depth to recursively
    # exapend relationships in addition to providing the URLs.
    #
    # @option opts [Integer] :max_inline Maximum number of objects to
    # expand inline in a relationship.
    #
    # @return [String] Json encoding of the object.
    def self.render_json(controller, obj, opts = {})
      opts[:pretty] = PRETTY_DEFAULT unless opts.has_key?(:pretty)
      Yajl::Encoder.encode(to_hash(controller, obj, opts),
                           :pretty => opts[:pretty])
    end

    # Render an object as a hash, using export and security properties
    # set by its controller.
    #
    # @param [RestController] controller Controller for the object being
    # serialized.
    #
    # @param [Sequel::Model] obj Object to encode.
    #
    # @option opts [Integer] :inline_relations_depth Depth to recursively
    # exapend relationships in addition to providing the URLs.
    #
    # @option opts [Integer] :max_inline Maximum number of objects to
    # expand inline in a relationship.
    #
    # @param [Integer] depth The current recursion depth.
    #
    # @param [Array] parents The recursion stack of classes that
    # we have expanded through.
    #
    # @return [Hash] Hash encoding of the object.
    def self.to_hash(controller, obj, opts, depth=0, parents=[])
      rel_hash = relations_hash(controller, obj, opts, depth, parents)
      entity_hash = obj.to_hash.merge(rel_hash)

      metadata_hash = {
        "guid" => obj.guid,
        "url" => controller.url_for_guid(obj.guid),
        "created_at" => obj.created_at,
      }

      if obj.respond_to?(:updated_at)
        metadata_hash["updated_at"] = obj.updated_at
      end

      {"metadata" => metadata_hash, "entity" => entity_hash}
    end

    def self.relations_hash(controller, obj, opts, depth, parents)
      inline_relations_depth = opts[:inline_relations_depth] || INLINE_RELATIONS_DEFAULT
      max_number_of_associated_objects_to_inline = opts[:max_inline] || MAX_INLINE_DEFAULT

      {}.tap do |res|
        parents.push(controller)
        res.merge!(serialize_relationships(controller.to_one_relationships, controller, depth, obj, opts, parents, inline_relations_depth))
        res.merge!(serialize_relationships(controller.to_many_relationships, controller, depth, obj, opts, parents, inline_relations_depth, max_number_of_associated_objects_to_inline))
        parents.pop
      end
    end

    def self.serialize_relationships(relationships, controller, depth, obj, opts, parents, inline_relations_depth, max_number_of_associated_objects_to_inline= nil)
      response = {}
      (relationships || {}).each do |association_name, association|

        associated_model = get_associated_model_klazz_for(obj, association_name)
        next unless associated_model

        associated_controller = get_controller_for(associated_model)

        associated_model_instances = obj.user_visible_relationship_dataset(association_name,
          VCAP::CloudController::SecurityContext.current_user,
          VCAP::CloudController::SecurityContext.admin?)

        associated_url = association_endpoint(
          controller, associated_controller, obj, associated_model_instances, association)

        response["#{association_name}_url"] = associated_url if associated_url
        next if association.link_only?

        if depth < inline_relations_depth && !parents.include?(associated_controller)
          if association.is_a?(ControllerDSL::ToOneAttribute)
            associated_model_instance = associated_model_instances.first
            if associated_model_instance
              response[association_name.to_s] = to_hash(associated_controller, associated_model_instance, opts, depth + 1, parents)
            end
          else
            if associated_model_instances.count <= max_number_of_associated_objects_to_inline
              response[association_name.to_s] = associated_model_instances.map do |associated_model_instance|
                to_hash(associated_controller, associated_model_instance, opts, depth + 1, parents)
              end
            end
          end
        end
      end

      response
    end

    private

    def self.get_associated_model_klazz_for(obj, name)
      ar = obj.model.association_reflection(name)
      return unless ar
      ar.associated_class
    end

    def self.get_controller_for(model)
      VCAP::CloudController.controller_from_model_name(model.name)
    end

    def self.association_endpoint(controller, associated_controller, obj, associated_model_instances, association)
      if association.is_a?(ControllerDSL::ToOneAttribute)
        if (associated_model_instance = associated_model_instances.first)
          associated_controller.url_for_guid(associated_model_instance.guid)
        end
      else
        "#{controller.url_for_guid(obj.guid)}/#{association.name}"
      end
    end
  end

  module EntityOnlyObjectSerialization
    def self.to_hash(controller, obj, opts, depth=0, parents=[])
      rel_hash = ObjectSerialization.relations_hash(controller, obj, opts, depth, parents)
      obj.to_hash.merge(rel_hash)
    end
  end
end
