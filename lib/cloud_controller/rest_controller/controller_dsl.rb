# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  # DSL that is available inside define_attributes on a rest controller
  # class.
  module ControllerDSL
    include VCAP::RestAPI

    # these aren't *really* necessary, but it makes .inspect on them
    # a bit more informative
    class ToManyAttribute < NamedAttribute; end
    class ToOneAttribute  < NamedAttribute; end

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
