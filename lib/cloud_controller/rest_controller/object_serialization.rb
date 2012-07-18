# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  # Serialize objects according in the format required by the vcap
  # rest api.
  #
  # TODO: migrate this to be like messages and routes in that
  # it is included and mixed in rather than having the controller
  # passed into it?
  #
  # FIXME: add authz checks to attribures and inlined relations

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

      id = obj.guid || obj.id
      metadata_hash = {
        "guid"  => id,
        "url" => controller.url_for_id(id),
        "created_at" => obj.created_at,
        "updated_at" => obj.updated_at
      }

      { "metadata" => metadata_hash, "entity" => entity_hash }
    end

    private

    def self.relations_hash(controller, obj, opts, depth, parents)
      target_depth = opts[:inline_relations_depth] || INLINE_RELATIONS_DEFAULT
      max_inline = opts[:max_inline] || MAX_INLINE_DEFAULT
      res = {}

      parents.push(controller)

      controller.to_many_relationships.each do |name, attr|
        ar = controller.model.association_reflection(name)
        other_model = ar.associated_class
        other_controller = VCAP::CloudController.controller_from_model_name(other_model.name)
        q_key = "#{ar[:reciprocol].to_s.singularize}_guid"
        res["#{name}_url"] = "#{controller.url_for_id(obj.guid)}/#{name}"

        others = other_model.user_visible.filter(ar[:reciprocol] => [obj])

        # TODO: replace depth with parents.size
        if (others.count <= max_inline &&
            depth < target_depth && !parents.include?(other_controller))
          res[name.to_s] = others.map do |other|
            other_controller = VCAP::CloudController.controller_from_model(other)
            to_hash(other_controller, other, opts, depth + 1, parents)
          end
        end
      end

      controller.to_one_relationships.each do |name, attr|
        ar = controller.model.association_reflection(name)
        other_model = ar.associated_class
        other_controller = VCAP::CloudController.controller_from_model_name(other_model.name)
        other = obj.send(name)
        res["#{name}_url"] = other_controller.url_for_id(other.guid) if other
        if other && depth < target_depth && !parents.include?(other_controller)
          other_controller = VCAP::CloudController.controller_from_model(other)
          res[name.to_s] = to_hash(other_controller, other,
                                   opts, depth + 1, parents)
        end
      end

      parents.pop
      res
    end

  end
end
