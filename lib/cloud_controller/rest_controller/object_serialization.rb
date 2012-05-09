# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  # Serialize objects according in the format required by the vcap
  # rest api.
  #
  # TODO: migrate this to be like messages and routes in that
  # it is included and mixed in rather than having the controller
  # passed into it?
  module ObjectSerialization
    PRETTY_DEFAULT = true

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
    # @return [String] Json encoding of the object.
    def self.render_json(controller, obj, opts = {})
      opts[:pretty] = PRETTY_DEFAULT unless opts.has_key?(:pretty)
      Yajl::Encoder.encode(to_hash(controller, obj), :pretty => opts[:pretty])
    end

    # Render an object as a hash, using export and security properties
    # set by its controller.
    #
    # @param [RestController] controller Controller for the object being
    # serialized.
    #
    # @param [Sequel::Model] obj Object to encode.
    #
    # @return [Hash] Hash encoding of the object.
    def self.to_hash(controller, obj)
      rel_hash = relations_hash(controller, obj)

      # TODO: this needs to do a read authz check.
      entity_hash = obj.to_hash.merge(rel_hash)

      metadata_hash = {
        "id"  => obj.id,
        "url" => controller.url_for_id(obj.id),
        "created_at" => obj.created_at,
        "updated_at" => obj.updated_at
      }

      { "metadata" => metadata_hash, "entity" => entity_hash }
    end

    private

    def self.relations_hash(controller, obj)
      res = {}
      # FIXME: to_one also
      controller.to_many_relationships.each do |name, attr|
        key = "#{controller.class_basename.underscore}_id"
        res["#{name}_url"] = "/v2/#{name}?q=#{key}:#{obj.id}"
      end
      res
    end
  end
end
