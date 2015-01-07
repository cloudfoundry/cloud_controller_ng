module VCAP::RestAPI
  # A NamedAttribute defines an attribute used in a rest controller
  #
  # These are ultimately used to capture the attributes allowed to be
  # fetched/set on a controller.  These ultimately get used to auto-generate
  # a Membrane based json validator on a per request type basis.
  class NamedAttribute
    attr_reader :name, :default, :has_default
    alias_method :has_default?, :has_default

    # Create a NamedAttribute.  By default, the attribute is considered to
    # be required.
    #
    # @param [Symbol] Name of the attribute.
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
    def initialize(name, opts={})
      @name        = name
      @exclude_in  = Set.new(Array(opts[:exclude_in]))
      @optional_in = Set.new(Array(opts[:optional_in]))
      @default     = opts[:default]
      @has_default = opts.key?(:default)
    end

    # Predicate to check if the attribute is excluded for a certain type of
    # operation.
    #
    # @param [Symbol] operation_type The type of operation.
    #
    # @return [Boolean] True if the attribute should be excluded.
    def exclude_in?(operation_type)
      @exclude_in.include?(operation_type)
    end

    # Predicate to check if the attribute is optional for a certain type of
    # operation.
    #
    # @param [Symbol] operation_type The type of operation.
    #
    # @return [Boolean] True if the attribute is optional.
    def optional_in?(operation_type)
      @optional_in.include?(operation_type)
    end
  end

  class SchemaAttribute < NamedAttribute
    attr_reader :schema, :block

    # A SchemaAttribute has an associated Membrane schema.
    #
    # @param [Symbol] name Name of the attribute.
    #
    # @param [Class] The Membrane schema or class type of the named attribute.
    #
    # @option opts [[Symbol]] :exclude_in One or more symbols representing
    # an operation types that the attribute is allowed in, e.g.
    # :exclude_in => :create, or :exclude_in => [:read, :enumerate], etc
    #
    # @option opts [[Symbol]] :exclude_in One or more symbols representing
    # an operation types that the attribute is allowed in, e.g.
    # :exclude_in => :create, or :exclude_in => [:read, :enumerate], etc
    #
    # @option opts [Object] :default default value for the attribute if it
    # isn't supplied.
    def initialize(name, schema, opts={})
      if schema.respond_to?(:call)
        @block = schema
        @schema = nil
      else
        @schema = schema
        @block = nil
      end
      super(name, opts)
    end
  end
end
