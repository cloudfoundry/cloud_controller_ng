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
    # against, keyed by guid, or nil if inline relationships should be appended to
    # parents instead of being orphaned.
    #
    # @return [Hash] Hash encoding of the object.
    def serialize(controller, obj, opts, orphans=nil)
      to_hash(controller, obj, opts, 0, [], orphans)
    end

    private

    def to_hash(controller, obj, opts, depth, parents, orphans=nil)
      export_attrs = opts.delete(:export_attrs)

      if obj.respond_to? :transient_attrs
        export_attrs = obj.export_attrs if export_attrs.nil?
        export_attrs += obj.transient_attrs
      end

      rel_hash = relations_hash(controller, obj, opts, depth, parents, orphans)
      obj_hash = obj.to_hash(attrs: export_attrs)

      entity_hash = obj_hash.merge(rel_hash)

      metadata_hash = {
        'guid' => obj.guid,
        'url' => controller.url_for_guid(obj.guid),
        'created_at' => obj.created_at,
      }

      if obj.respond_to?(:updated_at)
        metadata_hash['updated_at'] = obj.updated_at
      end

      { 'metadata' => metadata_hash, 'entity' => entity_hash }
    end

    def relations_hash(controller, obj, opts, depth, parents, orphans=nil)
      opts = opts.merge({
        inline_relations_depth: opts[:inline_relations_depth] || INLINE_RELATIONS_DEFAULT,
        max_number_of_associated_objects_to_inline: opts[:max_inline] || MAX_INLINE_DEFAULT
      })

      {}.tap do |res|
        parents.push(controller)

        res.merge!(
          serialize_relationships(
            controller.to_one_relationships,
            controller, depth, obj, opts, parents, orphans,
        ))

        res.merge!(
          serialize_relationships(
            controller.to_many_relationships,
            controller, depth, obj, opts, parents, orphans,
        ))

        parents.pop
      end
    end

    def serialize_relationships(relationships, controller, depth, obj, opts, parents, orphans)
      response = {}
      (relationships || {}).each do |relationship_name, association|
        associated_model = get_associated_model_class_for(obj, association.association_name)
        next unless associated_model
        associated_controller = VCAP::CloudController.controller_from_model_name(associated_model.name)
        next unless associated_controller
        add_relationship_url_to_response(response, controller, associated_controller, relationship_name, association, obj)
        next if relationship_link_only?(association, associated_controller, relationship_name, opts, depth, parents)
        associated_model_instance = get_preloaded_association_contents!(obj, association)

        if association.is_a?(ControllerDSL::ToOneAttribute)
          serialize_to_one_relationship(response, associated_model_instance, associated_controller, relationship_name, depth, opts, parents, orphans)
        else
          serialize_to_many_relationship(response, associated_model_instance, associated_controller, relationship_name, depth, opts, parents, orphans)
        end
      end
      response
    end

    def serialize_to_one_relationship(response, associated_model_instance, associated_controller, relationship_name, depth, opts, parents, orphans)
      return if associated_model_instance.nil?

      if orphans
        orphans[associated_model_instance.guid] ||= to_hash(associated_controller, associated_model_instance, opts, depth + 1, parents, orphans)
      else
        response[relationship_name.to_s] = to_hash(associated_controller, associated_model_instance, opts, depth + 1, parents, orphans)
      end
    end

    def serialize_to_many_relationship(response, associated_model_instances, associated_controller, relationship_name, depth, opts, parents, orphans)
      return if associated_model_instances.count > opts[:max_number_of_associated_objects_to_inline]

      response[relationship_name.to_s] = associated_model_instances.map do |associated_model_instance|
        if orphans
          orphans[associated_model_instance.guid] ||= to_hash(associated_controller, associated_model_instance, opts, depth + 1, parents, orphans)
          associated_model_instance.guid
        else
          to_hash(associated_controller, associated_model_instance, opts, depth + 1, parents, orphans)
        end
      end
    end

    def add_relationship_url_to_response(response, controller, associated_controller, relationship_name, association, obj)
      if association.is_a?(ControllerDSL::ToOneAttribute)
        associated_model_instance = get_preloaded_association_contents!(obj, association)
        if associated_model_instance
          associated_url = associated_controller.url_for_guid(associated_model_instance.guid)
        end
      else
        associated_url = "#{controller.url_for_guid(obj.guid)}/#{relationship_name}"
      end

      response["#{relationship_name}_url"] = associated_url if associated_url
    end

    def relationship_link_only?(association, associated_controller, relationship_name, opts, depth, parents)
      return true if association.link_only?
      return true if opts[:exclude_relations] && opts[:exclude_relations].include?(relationship_name.to_s)
      return true if opts[:include_relations] && !opts[:include_relations].include?(relationship_name.to_s)
      depth >= opts[:inline_relations_depth] || parents.include?(associated_controller)
    end

    def get_preloaded_association_contents!(obj, association)
      unless obj.associations.key?(association.association_name.to_sym)
        raise NotLoadedAssociationError.new("Association #{association.association_name} on #{obj.inspect} must be preloaded")
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
    def to_hash(controller, obj, opts, depth, parents, orphans=nil)
      obj.to_hash.merge(relations_hash(controller, obj, opts, depth, parents, orphans))
    end
  end
end
