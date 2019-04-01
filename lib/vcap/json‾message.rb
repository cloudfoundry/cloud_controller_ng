# Copyright (c) 2009-2011 VMware, Inc
require 'rubygems'
require 'yajl'
require 'membrane'

class JsonMessage
  # Base error class that all other JsonMessage related errors should
  # inherit from
  class Error < StandardError
  end

  # Fields not defined properly.
  class DefinitionError < Error
  end

  # Failed to parse json during +decode+
  class ParseError < Error
  end

  # One or more field's values didn't match their schema
  class ValidationError < Error
    attr_reader :errors

    def initialize(errors)
      @errors = errors
    end

    def to_s
      err_strs = @errors.map { |f, e| "Field: #{f}, Error: #{e}" }
      err_strs.join(', ')
    end
  end

  class Field
    attr_reader :name, :schema, :required, :default

    def initialize(name, options={}, &blk)
      blk ||= lambda { |*_| options[:schema] || any }

      @name = name
      @schema = Membrane::SchemaParser.parse(&blk)
      @required = options[:required] || false
      @default = options[:default]

      if @required && @default
        raise DefinitionError.new("Cannot define a default value for required field #{name}")
      end

      validate(@default) if @default
    end

    def validate(value)
      @schema.validate(value)
    rescue Membrane::SchemaValidationError => e
      raise ValidationError.new({ name => e.message })
    end
  end

  class << self
    def fields
      @fields ||= {}
    end

    def decode(json)
      begin
        dec_json = Yajl::Parser.parse(json)
      rescue => e
        raise ParseError.new(e.to_s)
      end

      from_decoded_json(dec_json)
    end

    def from_decoded_json(dec_json)
      raise ParseError.new('Decoded JSON cannot be nil') unless dec_json

      errs = {}

      # Treat null values as if the keys aren't present. This isn't as strict
      # as one would like, but conforms to typical use cases.
      dec_json.delete_if { |k, v| v.nil? }

      # Collect errors by field
      fields.each do |name, field|
        err = nil
        if dec_json.key?(name.to_s)
          begin
            field.validate(dec_json[name.to_s])
          rescue ValidationError => e
            err = e.errors[name]
          end
        elsif field.required
          err = "Missing field #{name}"
        end

        errs[name] = err if err
      end

      raise ValidationError.new(errs) unless errs.empty?

      new(dec_json)
    end

    def required(name, schema=nil, &blk)
      define_field(name, schema: schema, required: true, &blk)
    end

    def optional(name, schema=nil, default=nil, &blk)
      define_field(name, schema: schema, default: default, &blk)
    end

    protected

    def define_field(name, options={}, &blk)
      name = name.to_sym

      fields[name] = Field.new(name, options, &blk)

      define_method(name) do
        set_default(name)
        @msg[name]
      end

      define_method("#{name}=") do |value|
        set_field(name, value)
      end
    end
  end

  def initialize(fields={})
    @msg = {}
    fields.each { |name, value| set_field(name, value) }
    set_defaults
  end

  def encode
    set_defaults

    missing_fields = {}

    self.class.fields.each do |name, field|
      if field.required && !@msg.key?(name)
        missing_fields[name] = "Missing field #{name}"
      end
    end

    raise ValidationError.new(missing_fields) unless missing_fields.empty?

    Yajl::Encoder.encode(@msg)
  end

  def extract(opts={})
    hash = @msg.dup
    hash = hash.stringify_keys if opts[:stringify_keys]
    hash.freeze
  end

  protected

  def set_field(name, value)
    name = name.to_sym
    field = self.class.fields[name]

    return unless field

    field.validate(value)
    @msg[name] = value
  end

  def set_defaults
    self.class.fields.each_key do |name|
      set_default(name)
    end
  end

  # rubocop:disable Naming/AccessorMethodName
  def set_default(name)
    unless @msg.key?(name)
      field = self.class.fields[name]
      if field
        @msg[name] = field.default unless field.default.nil?
      end
    end
  end
  # rubocop:enable Naming/AccessorMethodName
end
