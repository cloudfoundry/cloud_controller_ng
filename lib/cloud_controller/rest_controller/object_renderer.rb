require 'addressable/uri'

module VCAP::CloudController::RestController
  class ObjectRenderer
    def initialize(eager_loader, serializer, opts)
      @eager_loader = eager_loader
      @serializer = serializer

      @max_inline_relations_depth = opts.fetch(:max_inline_relations_depth)
      @default_inline_relations_depth = 0
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
    def render_json(controller, obj, opts)
      inline_relations_depth = opts[:inline_relations_depth] || @default_inline_relations_depth
      if inline_relations_depth > @max_inline_relations_depth
        raise VCAP::Errors::BadQueryParameter.new("inline_relations_depth must be <= #{@max_inline_relations_depth}")
      end

      eager_loaded_objects = @eager_loader.eager_load_dataset(
        obj.model.dataset,
        controller,
        default_visibility_filter,
        opts[:additional_visibility_filters] || {},
        inline_relations_depth,
      )

      eager_loaded_object = eager_loaded_objects.where(id: obj.id).all.first

      # The class of object and eager_loaded_object could be different
      # if they are part of STI. Attributes exported by the object
      # are the ones that are expected in the response.
      # (e.g. Domain vs SharedDomain < Domain)
      hash = @serializer.serialize(
        controller,
        eager_loaded_object,
        opts.merge(export_attrs: obj.model.export_attrs),
      )

      Yajl::Encoder.encode(hash, pretty: opts.fetch(:pretty, true))
    end

    private

    def default_visibility_filter
      user = VCAP::CloudController::SecurityContext.current_user
      admin = VCAP::CloudController::SecurityContext.admin?
      proc { |ds| ds.filter(ds.model.user_visibility(user, admin)) }
    end
  end
end
