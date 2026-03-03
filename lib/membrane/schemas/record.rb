require 'membrane/errors'
require 'membrane/schemas/base'

module Membrane
  module Schema
  end
end

class Membrane::Schemas::Record < Membrane::Schemas::Base
  attr_reader :schemas, :optional_keys

  def initialize(schemas, optional_keys=[])
    @optional_keys = Set.new(optional_keys)
    @schemas = schemas
  end

  def validate(object)
    HashValidator.new(object).validate
    KeyValidator.new(@optional_keys, @schemas, object).validate
  end

  def parse(&)
    other_record = Membrane::SchemaParser.parse(&)
    @schemas.merge!(other_record.schemas)
    @optional_keys << other_record.optional_keys

    self
  end

  class KeyValidator
    def initialize(optional_keys, schemas, object)
      @optional_keys = optional_keys
      @schemas = schemas
      @object = object
    end

    def validate
      key_errors = {}
      schema_keys = []
      @schemas.each do |k, schema|
        if @object.key?(k)
          schema_keys << k
          begin
            schema.validate(@object[k])
          rescue Membrane::SchemaValidationError => e
            key_errors[k] = e.to_s
          end
        elsif !@optional_keys.member?(k)
          key_errors[k] = 'Missing key'
        end
      end

      fail!(key_errors) unless key_errors.empty?
    end

    private

    def fail!(errors)
      emsg =
        if ENV['MEMBRANE_ERROR_USE_QUOTES']
          '{ ' + errors.map { |k, e| "'#{k}' => %q(#{e})" }.join(', ') + ' }'
        else
          '{ ' + errors.map { |k, e| "#{k} => #{e}" }.join(', ') + ' }'
        end
      raise Membrane::SchemaValidationError.new(emsg)
    end
  end

  class HashValidator
    def initialize(object)
      @object = object
    end

    def validate
      fail!(@object) unless @object.is_a?(Hash)
    end

    private

    def fail!(object)
      emsg = "Expected instance of Hash, given instance of #{object.class}"
      raise Membrane::SchemaValidationError.new(emsg)
    end
  end
end
