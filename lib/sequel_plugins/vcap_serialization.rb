require "yajl"

module Sequel::Plugins::VcapSerialization
  # This plugin implements serialization and deserialization of
  # Sequel::Models to/from hashes and json.

  module InstanceMethods
    # Return a hash of the model instance containing only the parameters
    # specified by export_attributes.
    #
    # @option opts [Array<String>] :only Only export an attribute if it is both
    # included in export_attributes and in the :only option.
    #
    # @return [Hash] The hash representation of the instance only containing
    # the attributes specified by export_attributes and the optional :only
    # parameter.
    def to_hash(opts = {})
      hash = {}
      redact_vals = opts[:redact]
      attrs = opts[:attrs] || self.class.export_attrs || []

      attrs.each do |k|
        if opts[:only].nil? || opts[:only].include?(k)
          value = send(k)
          if value.respond_to?(:nil_object?) && value.nil_object?
            hash[k.to_s] = nil
          else
            if !redact_vals.nil? && redact_vals.include?(k.to_s)
              hash[k.to_s] = '[PRIVATE DATA HIDDEN]'
            else
              hash[k.to_s] = value
            end
          end
        end
      end
      hash
    end

    # Return a json serialization of the model instance containing only
    # the parameters specified by export_attributes.
    #
    # @option opts [Array<String>] :only Only export an attribute if it is both
    # included in export_attributes and in the :only option.
    #
    # @return [String] The json serialization of the instance only containing
    # the attributes specified by export_attributes and the optional :only
    # parameter.
    def to_json(opts = {})
      Yajl::Encoder.encode(to_hash(opts))
    end

    # Update the model instance from the supplied json string.  Only update
    # attributes specified by import_attributes.
    #
    # @param [String] Json encoded representation of the updated attributes.
    #
    # @option opts [Array<String>] :only Only import an attribute if it is both
    # included in import_attributes and in the :only option.
    def update_from_json(json, opts = {})
      parsed = Yajl::Parser.new.parse(json)
      update_from_hash(parsed, opts)
    end

    # Update the model instance from the supplied hash.  Only update
    # attributes specified by import_attributes.
    #
    # @param [Hash] Hash of the updated attributes.
    #
    # @option opts [Array<String>] :only Only import an attribute if it is both
    # included in import_attributes and in the :only option.
    def update_from_hash(hash, opts = {})
      update_opts = self.class.update_or_create_options(hash, opts)

      # Cannot use update(update_opts) because it does not
      # update updated_at timestamp when no changes are being made.
      # Arguably this should avoid updating updated_at if nothing changed.
      set_all(update_opts)
      save
    end
  end

  module ClassMethods
    # Return a json serialization of data set containing only
    # the parameters specified by export_attributes.
    #
    # @option opts [Array<String>] :only Only export an attribute if it is both
    # included in export_attributes and in the :only option.
    #
    # @return [String] The json serialization of the data set only containing
    # the attributes specified by export_attributes and the optional :only
    # parameter.  The resulting data set is sorted by :id unless an order
    # is set via default_order_by.
    def to_json(opts = {})
      order_attr = @default_order_by || :id
      elements = order_by(Sequel.asc(order_attr)).map { |e| e.to_hash(opts) }
      Yajl::Encoder.encode(elements)
    end

    # Create a new model instance from the supplied json string.  Only include
    # attributes specified by import_attributes.
    #
    # @param [String] Json encoded representation attributes.
    #
    # @option opts [Array<String>] :only Only include an attribute if it is
    # both included in import_attributes and in the :only option.
    #
    # @return [Sequel::Model] The created model.
    def create_from_json(json, opts = {})
      hash = Yajl::Parser.new.parse(json)
      create_from_hash(hash, opts)
    end

    # Create and save a new model instance from the supplied json string.
    # Only include attributes specified by import_attributes.
    #
    # @param [Hash] Hash of the attributes.
    #
    # @option opts [Array<String>] :only Only include an attribute if it is
    # both included in import_attributes and in the :only option.
    #
    # @return [Sequel::Model] The created model.
    def create_from_hash(hash, opts = {})
      create_opts = update_or_create_options(hash, opts)
      create {|instance| instance.set_all(create_opts) }
    end

    # Instantiates, but does not save, a new model instance from the
    # supplied json string.  Only include # attributes specified by
    # import_attributes.
    #
    # @param [Hash] Hash of the attributes.
    #
    # @option opts [Array<String>] :only Only include an attribute if it is
    # both included in import_attributes and in the :only option.
    #
    # @return [Sequel::Model] The created model.
    def new_from_hash(hash, opts = {})
      create_opts = update_or_create_options(hash, opts)
      new(create_opts)
    end

    # Set the default order during a to_json on the model class.
    #
    # @param [Symbol] Name of the attribute to order by.
    def default_order_by(attribute)
      @default_order_by = attribute
    end

    # Set the default order during a to_json on the model class.
    #
    # @param [Array<Symbol>] List of attributes to include when serializing to
    # json or a hash.
    def export_attributes(*attributes)
      self.export_attrs = attributes
    end

    # @param [Array<Symbol>] List of attributes to include when importing
    # from json or a hash.
    def import_attributes(*attributes)
      self.import_attrs = attributes
    end

    # Not intended to be called by consumers of the API, but needed
    # by instance of the class, so it can't be made private.
    def update_or_create_options(hash, opts)
      results = {}
      attrs = self.import_attrs || []
      attrs = attrs - opts[:only] unless opts[:only].nil?
      attrs.each do |attr|
        key = nil
        if hash.has_key?(attr)
          key = attr
        elsif hash.has_key?(attr.to_s)
          key = attr.to_s
        end
        results[attr] = hash[key] unless key.nil?
      end
      results
    end

    attr_accessor :export_attrs, :import_attrs
  end
end
