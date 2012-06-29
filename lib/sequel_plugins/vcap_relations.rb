# Copyright (c) 2009-2012 VMware, Inc.

module Sequel::Plugins::VcapRelations
  module ClassMethods
    # Override many_to_one in order to add <relation>_guid
    # and <relation>_guid= methods.
    #
    # See the default many_to_one implementation for a description of the args
    # and return values.
    def many_to_one(name, opts = {})
      guid_attr = "#{name}_guid"

      define_method(guid_attr) do
        send(name).guid
      end

      define_method("#{guid_attr}=") do |val|
        ar = self.class.association_reflection(name)
        other = ar.associated_class[:guid => val]
        # FIXME: better error reporting
        return if(other.nil? && !val.nil?)
        send("#{name}=", other)
      end

      opts[:reciprocol] ||=
        self.name.split("::").last.underscore.to_sym
      super
    end

    # Override many_to_many in order to add an override the default Sequel
    # methods for many_to_many relationships.
    #
    # In particular, this enables support of bulk modifying relationships.
    #
    # See the default many_to_many implementation for a description of the args
    # and return values.
    def many_to_many(name, opts = {})
      singular_name = name.to_s.singularize
      ids_attr      = "#{singular_name}_ids"
      guids_attr    = "#{singular_name}_guids"

      define_method("add_#{singular_name}") do |other|
        # sequel is not capable of merging adds to a many_to_many association
        # like it is for a one_to_many and nds up throwing a db exception,
        # so lets squash the add
        if other.kind_of?(Integer)
          # FIXME: this is inefficient as it has to pull all ids
          super(other) unless send(ids_attr).include? other
        else
          super(other) unless send(name).include? other
        end
      end

      define_to_many_reciprocol(opts)
      define_to_many_methods(name, singular_name, ids_attr, guids_attr)
      super
    end

    # Override one_to_many in order to add an override the default Sequel
    # methods for one_to_many relationships.
    #
    # In particular, this enables support of bulk modifying relationships.
    #
    # See the default one_to_many implementation for a description of the args
    # and return values.
    def one_to_many(name, opts = {})
      singular_name = name.to_s.singularize
      ids_attr      = "#{singular_name}_ids"
      guids_attr    = "#{singular_name}_guids"

      define_to_many_reciprocol(opts)
      define_to_many_methods(name, singular_name, ids_attr, guids_attr)
      super
    end

    private

    def define_to_many_reciprocol(opts)
      opts[:reciprocol] ||=
        self.name.split("::").last.underscore.pluralize.to_sym
    end

    def define_to_many_methods(name, singular_name, ids_attr, guids_attr)

      define_method(ids_attr) do
        send(name).collect { |o| o.id }
      end

      define_method("add_#{singular_name}_by_guid") do |guid|
        ar = self.class.association_reflection(name)
        other = ar.associated_class[:guid => guid]
        # FIXME: better error reporting
        return if other.nil?
        send("add_#{singular_name}", other)
      end

      define_method("#{ids_attr}=") do |ids|
        return unless ids
        send("remove_all_#{name}") unless send(name).empty?
        ids.each { |i| send("add_#{singular_name}", i) }
      end

      define_method("#{guids_attr}") do
        send(name).collect { |o| o.guid }
      end

      define_method("#{guids_attr}=") do |guids|
        return unless guids
        send("remove_all_#{name}") unless send(name).empty?
        guids.each { |g| send("add_#{singular_name}_by_guid", g) }
      end

      define_method("remove_#{singular_name}_by_guid") do |guid|
        ar = self.class.association_reflection(name)
        other = ar.associated_class[:guid => guid]
        # FIXME: better error reporting
        return if other.nil?
        send("remove_#{singular_name}", other)
      end

      define_method("remove_#{singular_name}") do |other|
        if other.kind_of?(Integer)
          # FIXME: this is inefficient as it has to pull all ids
          super(other) if send(ids_attr).include? other
        else
          super(other) if send(name).include? other
        end
      end
    end
  end
end
