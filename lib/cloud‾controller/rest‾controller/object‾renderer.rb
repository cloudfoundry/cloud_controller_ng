require 'addressable/uri'

module VCAP::CloudController::RestController
  class ObjectRenderer
    attr_reader :object_transformer

    def initialize(eager_loader, serializer, opts)
      @eager_loader = eager_loader
      @serializer = serializer

      @max_inline_relations_depth = opts.fetch(:max_inline_relations_depth)
      @default_inline_relations_depth = 0

      @object_transformer = opts[:object_transformer]
    end

    # Render an object to json, using export and security properties
    # set by its controller.
    #
    # @param [RestController] controller Controller for the object being
    # encoded.
    #
    # @param [Sequel::Model] obj Object to encode.
    #
    # @option opts [Boolean] :pretty Controls pretty formatting of the encoded
    # json.  Defaults to true.
    #
    # @option opts [Integer] :inline_relations_depth Depth to recursively
    # expand relationships in addition to providing the URLs.
    #
    # @option opts [Integer] :max_inline Maximum number of objects to
    # expand inline in a relationship.
    def render_json(controller, obj, opts)
      inline_relations_depth = opts[:inline_relations_depth] || @default_inline_relations_depth
      if inline_relations_depth > @max_inline_relations_depth
        raise CloudController::Errors::ApiError.new_from_details('BadQueryParameter', "inline_relations_depth must be <= #{@max_inline_relations_depth}")
      end

      eager_loaded_objects = @eager_loader.eager_load_dataset(
        obj.model.dataset,
        controller,
        opts[:default_visibility_filter] || default_visibility_filter,
        opts[:additional_visibility_filters] || {},
        inline_relations_depth,
      )

      eager_loaded_object = eager_loaded_objects.where(id: obj.id).all.first
      transform_opts = opts[:transform_opts] || {}
      object_transformer.transform(eager_loaded_object, transform_opts) if object_transformer

      # The class of object and eager_loaded_object could be different
      # if they are part of STI. Attributes exported by the object
      # are the ones that are expected in the response.
      # (e.g. Domain vs SharedDomain < Domain)
      export_attributes = eager_loaded_object.export_attrs
      if obj.respond_to? :transient_attrs
        obj.transient_attrs.each { |attr| eager_loaded_object.send("#{attr}=", obj.send(attr)) }
        export_attributes += obj.transient_attrs
      end

      hash = @serializer.serialize(
        controller,
        eager_loaded_object,
        opts.merge(export_attrs: export_attributes),
      )

      MultiJson.dump(hash, pretty: opts.fetch(:pretty, true))
    end

    def render_json_with_read_privileges(controller, obj, opts)
      render_json(controller, obj, opts.merge(default_visibility_filter: default_visibility_filter_with_read_privileges))
    end

    private

    def default_visibility_filter
      access_context = VCAP::CloudController::Security::AccessContext.new
      proc { |ds| ds.filter(ds.model.user_visibility(access_context.user, access_context.admin_override)) }
    end

    def default_visibility_filter_with_read_privileges
      access_context = VCAP::CloudController::Security::AccessContext.new
      proc { |ds| ds.filter(ds.model.user_visibility_for_read(access_context.user, access_context.admin_override)) }
    end
  end
end
