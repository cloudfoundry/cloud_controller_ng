require 'addressable/uri'

module VCAP::CloudController::RestController
  class ObjectRenderer
    def self.render_json(controller, obj, opts)
      new(controller, obj, opts, PreloadedObjectSerializer.new).render_json
    end

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
    def initialize(controller, obj, opts, serializer)
      @controller = controller
      @obj = obj
      @opts = opts

      @eager_loader = SecureEagerLoader.new
      @serializer = serializer

      @inline_relations_depth = opts[:inline_relations_depth] || 0
      @additional_visibility_filters = opts[:additional_visibility_filters] || {}

      @pretty = opts[:pretty] || false
      @pretty = true unless opts.has_key?(:pretty)
    end

    def render_json
      eager_loaded_objects = eager_load_dataset(@obj.model.dataset)
      eager_loaded_object  = eager_loaded_objects.where(id: @obj.id).all.first
      hash = serialize(eager_loaded_object)
      Yajl::Encoder.encode(hash, pretty: @pretty)
    end

    private

    def eager_load_dataset(dataset)
      user = VCAP::CloudController::SecurityContext.current_user
      admin = VCAP::CloudController::SecurityContext.admin?
      default_visibility_filter = proc { |ds| ds.filter(ds.model.user_visibility(user, admin)) }

      @eager_loader.eager_load_dataset(
        dataset,
        @controller,
        default_visibility_filter,
        @additional_visibility_filters,
        @inline_relations_depth,
      )
    end

    def serialize(obj)
      # The class of object and eager_loaded_object could be different
      # if they are part of STI. Attributes exported by the object
      # are the ones that are expected in the response.
      # (e.g. Domain vs SharedDomain < Domain)
      serialize_ops = @opts.merge(export_attrs: @obj.model.export_attrs)

      @serializer.serialize(@controller, obj, serialize_ops)
    end
  end

  class EntityOnlyObjectRenderer
    def self.render_json(controller, obj, opts)
      new(controller, obj, opts, UnsafeEntityOnlyObjectSerializer.new).render_json
    end
  end
end
