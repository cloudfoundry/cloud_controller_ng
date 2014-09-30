module VCAP::CloudController::RestController
  class PreloadedObjectSerializer
    class NotLoadedAssociationError < StandardError; end

    INLINE_RELATIONS_DEFAULT = 0
    MAX_INLINE_DEFAULT = 50

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
    # @param [Hash] orphans A hash to accumulate orphaned inline relationships 
    # against keyed by guid, or nil if inline relationships should be appended to 
    # parents instead of being orphaned.
    #
    # @return [Hash] Hash encoding of the object.
    def serialize(controller, obj, opts, orphans=nil)
      to_hash(controller, obj, opts, 0, [], orphans)
    end

    private

    def to_hash(controller, obj, opts, depth, parents, orphans=nil)
      export_attrs = opts.delete(:export_attrs)

      rel_hash = relations_hash(controller, obj, opts, depth, parents, orphans)
      obj_hash = obj.to_hash(attrs: export_attrs)

      entity_hash = obj_hash.merge(rel_hash)

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

    def relations_hash(controller, obj, opts, depth, parents, orphans=nil)
      inline_relations_depth = opts[:inline_relations_depth] || INLINE_RELATIONS_DEFAULT
      max_number_of_associated_objects_to_inline = opts[:max_inline] || MAX_INLINE_DEFAULT
      relationships_to_exclude = opts[:exclude_relations] ? opts[:exclude_relations].split(',') : []
      relationships_to_include = opts[:include_relations] ? opts[:include_relations].split(',') : []

      {}.tap do |res|
        parents.push(controller)

        res.merge!(serialize_relationships(
          controller.to_one_relationships,
          relationships_to_exclude,
          relationships_to_include,
          controller, depth, obj, opts, parents, orphans,
          inline_relations_depth,
        ))

        res.merge!(serialize_relationships(
          controller.to_many_relationships,
          relationships_to_exclude,
          relationships_to_include,
          controller, depth, obj, opts, parents, orphans,
          inline_relations_depth,
          max_number_of_associated_objects_to_inline,
        ))

        parents.pop
      end
    end

    def serialize_relationships(relationships, relationships_to_exclude, relationships_to_include, controller, depth, obj, opts, parents, orphans, inline_relations_depth, max_number_of_associated_objects_to_inline=nil)
      response = {}
      (relationships || {}).each do |relationship_name, association|
        associated_model = get_associated_model_class_for(obj, association.association_name)
        next unless associated_model

        associated_controller = VCAP::CloudController.controller_from_model_name(associated_model.name)
        if association.is_a?(ControllerDSL::ToOneAttribute)
          associated_model_instance = get_preloaded_association_contents!(obj, association)
          if associated_model_instance
            associated_url = associated_controller.url_for_guid(associated_model_instance.guid)
          end
        else
          associated_url = "#{controller.url_for_guid(obj.guid)}/#{relationship_name}"
        end

        response["#{relationship_name}_url"] = associated_url if associated_url
        next if association.link_only?

        next if relationships_to_exclude.include?(relationship_name.to_s)
        next unless relationships_to_include.length == 0 || relationships_to_include.include?(relationship_name.to_s)

        if depth < inline_relations_depth && !parents.include?(associated_controller)
          if association.is_a?(ControllerDSL::ToOneAttribute)
            if associated_model_instance
              if orphans.nil?
                response[relationship_name.to_s] = to_hash(associated_controller, associated_model_instance, opts, depth + 1, parents, orphans)
              elsif !orphans[associated_model_instance.guid]
                orphans[associated_model_instance.guid] = to_hash(associated_controller, associated_model_instance, opts, depth + 1, parents, orphans)
              end
            end
          else
            associated_model_instances = get_preloaded_association_contents!(obj, association)
            if associated_model_instances.count <= max_number_of_associated_objects_to_inline
              if orphans == nil
                response[relationship_name.to_s] = associated_model_instances.map do |associated_model_instance|
                  to_hash(associated_controller, associated_model_instance, opts, depth + 1, parents, orphans)
                end
              else
                response[relationship_name.to_s] = associated_model_instances.map do |associated_model_instance|
                  unless orphans[associated_model_instance.guid]
                    orphans[associated_model_instance.guid] = to_hash(associated_controller, associated_model_instance, opts, depth + 1, parents, orphans)
                  end
                end
              end
            end
          end
        end
      end

      response
    end

    def get_preloaded_association_contents!(obj, association)
      unless obj.associations.has_key?(association.association_name.to_sym)
        raise NotLoadedAssociationError,
          "Association #{association.association_name} on #{obj.inspect} must be preloaded"
      end
      obj.associations[association.association_name]
    end

    def get_associated_model_class_for(obj, name)
      model_association = obj.model.association_reflection(name)
      if model_association
        model_association.associated_class
      end
    end
  end

  class EntityOnlyPreloadedObjectSerializer < PreloadedObjectSerializer
    def to_hash(controller, obj, opts, depth, parents, orhpans=nil)
      obj.to_hash.merge(relations_hash(controller, obj, opts, depth, parents, orphans))
    end
  end
end
