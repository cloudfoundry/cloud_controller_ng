# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  module ControllerDSL
    include VCAP::RestAPI

    # these aren't *really* necessary, but it makes .inspect on them
    # a bit more informative
    class ToManyAttribute < NamedAttribute; end
    class ToOneAttribute  < NamedAttribute; end

    def initialize(controller)
      @controller = controller
    end

    def attribute(name, schema, opts = {})
      attributes[name] = SchemaAttribute.new(name, schema, opts)
    end

    def to_many(name, opts = {})
      to_many_relationships[name] = ToManyAttribute.new(name, opts)
    end

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
