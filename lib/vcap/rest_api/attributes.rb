# Copyright (c) 2009-2012 VMware Inc.

module VCAP::RestAPI
  # A NamedAttribute defines an attribute used in a rest controller
  #
  # These are ultimately used to capture the attributes allowed to be
  # fetched/set on a controller.  These ultimately get used to auto-generate
  # a JsonSchema (and soon to be converted to Membrane) based json validator
  # on a per request type basis.
  class NamedAttribute
    attr_reader :name
    attr_reader :default

    # Create a NamedAttribute.  By default, the attribute is considered to
    # be required.
    #
    # @param name [Symbol] Name of the attribute.
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
    #
    # @return [NamedAttribute]
    def initialize(name, opts = {})
      @name        = name
      @exclude_in  = Set.new(Array(opts[:exclude_in]))
      @optional_in = Set.new(Array(opts[:optional_in]))
      @default     = opts[:default]
    end

    # Predicate to check if the attribute is excluded for a certain type of
    # operation.
    #
    # @param name [Symbol] Name of the attribute
    #
    # @option opts [Symbol] Name of the attribute
    #
    # @return [Boolean]
    def exclude_in?(operation_type)
      @exclude_in.include?(operation_type)
    end

    # Predicate to check if the attribute is optional for a certain type of
    # operation.
    #
    # @param name [Symbol] Name of the attribute
    #
    # @option opts [Symbol] Name of the attribute
    #
    # @return [Boolean]
    def optional_in?(operation_type)
      @optional_in.include?(operation_type)
    end
  end

  class SchemaAttribute < NamedAttribute
    attr_reader :schema

    # A SchemaAttribute has an associated JsonSchema.  (Soon to be replaced
    # with Membrane).
    #
    # @param name [Symbol] Name of the attribute.
    #
    # @param schema [Class] Clas
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
    #
    # @return [SchemaAttribute]
    def initialize(name, schema, opts = {})
      @schema = schema
      super(name, opts)
    end
  end
end
