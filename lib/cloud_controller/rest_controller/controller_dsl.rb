module VCAP::CloudController::RestController
  # DSL that is available inside define_attributes on a rest controller
  # class.
  module ControllerDSL
    include VCAP::RestAPI

    class ToRelationshipAttribute < NamedAttribute
      attr_reader :association_name

      def initialize(name, opts = {})
        @association_name = opts[:association_name] || name
        @link_only = opts[:link_only] || false
        super
      end

      def link_only?
        @link_only
      end
    end

    class ToManyAttribute < ToRelationshipAttribute; end
    class ToOneAttribute < ToRelationshipAttribute; end

    def initialize(controller)
      @controller = controller
    end

    # Define an attribute for the api endpoint
    #
    # @param [Symbol] name Name of the attribute.
    #
    # @param [Class] schema The Membrane schema or class type of the
    # named attribute.
    #
    # @option opts [[Symbol]] :exclude_in One or more symbols representing
    # an operation types that the attribute is allowed in, e.g.
    # :exclude_in => :create, or :exclude_in => [:read, :enumerate], etc
    #
    # @option opts [[Symbol]] :optional_in One or more symbols representing
    # an operation types that the attribute is considered optional in.
    #
    # @option opts [Object] :default default value for the attribute if it
    # isn't supplied.
    def attribute(name, schema, opts = {})
      attributes[name] = SchemaAttribute.new(name, schema, opts)
    end

    # Define a to_many relationship for the api endpoint.
    #
    # @param [Symbol] name Name of the relationship.
    #
    # @option opts [[Symbol]] :exclude_in One or more symbols representing
    # an operation types that the attribute is allowed in, e.g.
    # :exclude_in => :create, or :exclude_in => [:read, :enumerate], etc
    #
    # @option opts [[Symbol]] :optional_in One or more symbols representing
    # an operation types that the attribute is considered optional in.
    def to_many(name, opts = {})
      to_many_relationships[name] = ToManyAttribute.new(name, opts)
    end

    # Define a to_one relationship for the api endpoint.
    #
    # @param [Symbol] name Name of the relationship.
    #
    # @option opts [[Symbol]] :exclude_in One or more symbols representing
    # an operation types that the attribute is allowed in, e.g.
    # :exclude_in => :create, or :exclude_in => [:read, :enumerate], etc
    #
    # @option opts [[Symbol]] :optional_in One or more symbols representing
    # an operation types that the attribute is considered optional in.
    def to_one(name, opts = {})
      to_one_relationships[name] = ToOneAttribute.new(name, opts)
    end

    private

    def attributes
      @controller.attributes ||= {}
    end

    def to_many_relationships
      @controller.to_many_relationships ||= {}
    end

    def to_one_relationships
      @controller.to_one_relationships ||= {}
    end
  end
end
