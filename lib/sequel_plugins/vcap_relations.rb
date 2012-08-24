# Copyright (c) 2009-2012 VMware, Inc.

module Sequel::Plugins::VcapRelations
  # Depend on the instance_hooks plugin.
  def self.apply(model)
    model.plugin(:instance_hooks)
  end

  module ClassMethods
    # Override many_to_one in order to add <relation>_guid
    # and <relation>_guid= methods.
    #
    # See the default many_to_one implementation for a description of the args
    # and return values.
    def many_to_one(name, opts = {})
      guid_attr = "#{name}_guid"

      define_method(guid_attr) do
        other = send(name)
        other.guid unless other.nil?
      end

      define_method("#{guid_attr}=") do |val|
        ar = self.class.association_reflection(name)
        other = ar.associated_class[:guid => val]
        # FIXME: better error reporting
        return if(other.nil? && !val.nil?)
        send("#{name}=", other)
      end

      opts[:reciprocal] ||=
        self.name.split("::").last.underscore.pluralize.to_sym

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

      opts[:reciprocal] ||=
        self.name.split("::").last.underscore.pluralize.to_sym

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

      opts[:reciprocal] ||= self.name.split("::").last.underscore.to_sym

      define_to_many_methods(name, singular_name, ids_attr, guids_attr)
      super
    end

    private

    def define_to_many_methods(name, singular_name, ids_attr, guids_attr)
      diff_collections = proc do |a, b|
        cur_set = Set.new(a)
        new_set = Set.new(b)

        intersection = cur_set & new_set
        added = new_set - intersection
        removed = cur_set - intersection

        [added, removed]
      end

      define_method(ids_attr) do
        send(name).collect { |o| o.id }
      end

      define_method("add_#{singular_name}_by_guid") do |guid|
        ar = self.class.association_reflection(name)
        other = ar.associated_class[:guid => guid]
        # FIXME: better error reporting
        return if other.nil?
        if pk
          send("add_#{singular_name}", other)
        else
          after_save_hook { send("add_#{singular_name}", other) }
        end
      end

      define_method("#{ids_attr}=") do |ids|
        return unless ids
        ds = send(name)
        ds.each { |r| send("remove_#{singular_name}", r) unless ids.include?(r.id) }
        ids.each { |i| send("add_#{singular_name}", i) }
      end

      define_method("#{guids_attr}") do
        send(name).collect { |o| o.guid }
      end

      define_method("#{guids_attr}=") do |guids|
        return unless guids
        current_guids = send(name).map { |o| o.guid }
        (added, removed) = diff_collections.call(current_guids, guids)
        removed.each { |g| send("remove_#{singular_name}_by_guid", g) }
        added.each   { |g| send("add_#{singular_name}_by_guid", g) }
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
