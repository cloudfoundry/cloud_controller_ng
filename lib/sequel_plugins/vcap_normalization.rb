# Copyright (c) 2009-2012 VMware, Inc.

module Sequel::Plugins::VcapNormalization
  module InstanceMethods
    # Strips attributes of the model if requested.
    def []=(k, v)
      v = strip_if_needed(k, v)
      super(k, v)
    end

    private

    def strip_if_needed(k, v)
      strip_attrs = self.class.strip_attrs || {}
      v = v.strip if strip_attrs.include?(k) && v.respond_to?(:strip)
      v
    end
  end

  module ClassMethods
    # Specify the attributes to perform whitespace normalization on
    #
    # @param [Array<Symbol>] List of attributes to include when performing
    # whitespace normalization.
    def strip_attributes(*attributes)
      self.strip_attrs = attributes
    end

    attr_accessor :strip_attrs
  end
end
