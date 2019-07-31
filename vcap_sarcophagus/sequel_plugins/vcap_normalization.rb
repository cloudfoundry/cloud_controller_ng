module Sequel::Plugins::VcapNormalization
  module InstanceMethods
    # Strips attributes of the model if requested.
    def []=(key, value)
      value = strip_if_needed(key, value)
      super(key, value)
    end

    private

    def strip_if_needed(key, value)
      strip_attrs = self.class.strip_attrs || {}
      value = value.strip if strip_attrs.include?(key) && value.respond_to?(:strip)
      value
    end
  end

  module ClassMethods
    # Specify the attributes to perform whitespace normalization on
    #
    # @param [Array<Symbol>] attributes - List of attributes to include when performing
    # whitespace normalization.
    def strip_attributes(*attributes)
      self.strip_attrs = attributes
    end

    attr_accessor :strip_attrs
  end
end
