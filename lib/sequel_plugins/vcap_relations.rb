# Copyright (c) 2009-2012 VMware, Inc.

module Sequel::Plugins::VcapRelations
  module ClassMethods
    # Override many_to_many in order to add an override the default Sequel
    # methods for many_to_many relationships.
    #
    # In particular, this enables support of bulk modifying relationships.
    #
    # See the default many_to_many implementation for a description of the args
    # and return values.
    def many_to_many(name, *args)
      singular_name = name.to_s.singularize
      ids_attribute = "#{singular_name}_ids"

      define_method("add_#{singular_name}") do |other|
        # sequel is not capable of merging adds to a many_to_many association
        # like it is for a one_to_many and nds up throwing a db exception,
        # so lets squash the add
        if other.kind_of?(Integer)
          # FIXME: this is inefficient as it has to pull all ids
          super(other) unless send(ids_attribute).include? other
        else
          super(other) unless send(name).include? other
        end
      end

      define_method("remove_#{singular_name}") do |other|
        if other.kind_of?(Integer)
          # FIXME: this is inefficient as it has to pull all ids
          super(other) if send(ids_attribute).include? other
        else
          super(other) if send(name).include? other
        end
      end

      define_method(ids_attribute) do
        ids = []
        send(name).each { |o| ids << o.id }
        ids
      end

      define_method("#{ids_attribute}=") do |ids|
        return unless ids
        send("remove_all_#{name}") unless send(name).empty?
        ids.each { |i| send("add_#{singular_name}", i) }
      end

      super
    end

    # Override one_to_many in order to add an override the default Sequel
    # methods for one_to_many relationships.
    #
    # In particular, this enables support of bulk modifying relationships.
    #
    # See the default one_to_many implementation for a description of the args
    # and return values.
    def one_to_many(name, *args)
      singular_name = name.to_s.singularize
      ids_attribute = "#{singular_name}_ids"

      define_method(ids_attribute) do
        ids = []
        send(name).each { |o| ids << o.id }
        ids
      end

      define_method("#{ids_attribute}=") do |ids|
        return unless ids
        send("remove_all_#{name}") unless send(name).empty?
        ids.each { |i| send("add_#{singular_name}", i) }
      end

      define_method("remove_#{singular_name}") do |other|
        if other.kind_of?(Integer)
          # FIXME: this is inefficient as it has to pull all ids
          super(other) if send(ids_attribute).include? other
        else
          super(other) if send(name).include? other
        end
      end

      super
    end
  end
end
