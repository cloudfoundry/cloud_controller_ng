# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  class TemplateObj
    attr_accessor :attributes

    def initialize(klass, attribute_names)
      @klass = klass
      @obj = klass.make
      @attributes = {}
      attribute_names.each do |attr|
        key = if @klass.associations.include?(attr.to_sym)
                "#{attr}_id"
              else
                attr
              end
        rel_attr = attr.to_s.chomp("_id")
        attr = rel_attr if @klass.associations.include?(rel_attr.to_sym)
        @attributes[key] = @obj.send(attr) if @obj.respond_to?(attr)
      end
      hash
    end

    def refresh
      @klass.associations.each do |name|
        association = @obj.send(name)
        key = "#{name}_id"
        @attributes[key] = association.class.make.id if @attributes[key]
      end
    end
  end
end
