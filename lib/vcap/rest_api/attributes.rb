# Copyright (c) 2009-2012 VMware Inc.

module VCAP::RestAPI
  class NamedAttribute
    attr_reader :name

    def initialize(name, opts)
      @opts = opts

      @opts[:exclude_in] ||= []
      unless opts[:exclude_in].respond_to?(:each)
        @opts[:exclude_in] = Array[opts[:exclude_in]]
      end

      @opts[:optional_in] ||= []
      unless opts[:optional_in].respond_to?(:each)
        @opts[:optional_in] = Array[opts[:optional_in]]
      end
    end

    def exclude_in?(type)
      @opts[:exclude_in].include?(type)
    end

    def optional_in?(type)
      @opts[:optional_in].include?(type)
    end

    def default
      @opts[:default]
    end
  end

  class SchemaAttribute < NamedAttribute
    attr_reader :schema

    def initialize(name, schema, opts)
      @schema = schema
      super(name, opts)
    end
  end

  class ToManyAttribute < NamedAttribute; end
  class ToOneAttribute  < NamedAttribute; end
end
