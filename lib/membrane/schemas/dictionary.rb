require "membrane/errors"
require "membrane/schemas/base"

module Membrane
  module Schema
  end
end

class Membrane::Schemas::Dictionary < Membrane::Schemas::Base
  attr_reader :key_schema
  attr_reader :value_schema

  def initialize(key_schema, value_schema)
    @key_schema = key_schema
    @value_schema = value_schema
  end

  def validate(object)
    HashValidator.new(object).validate
    MembersValidator.new(@key_schema, @value_schema, object).validate
  end

  class HashValidator
    def initialize(object)
      @object = object
    end

    def validate
      fail!(@object.class) if !@object.kind_of?(Hash)
    end

    private

    def fail!(klass)
      emsg = "Expected instance of Hash, given instance of #{klass}."
      raise Membrane::SchemaValidationError.new(emsg)
    end
  end

  class MembersValidator
    def initialize(key_schema, value_schema, object)
      @key_schema = key_schema
      @value_schema = value_schema
      @object = object
    end

    def validate
      errors = {}

      @object.each do |k, v|
        begin
          @key_schema.validate(k)
          @value_schema.validate(v)
        rescue Membrane::SchemaValidationError => e
          errors[k] = e.to_s
        end
      end

      fail!(errors) if errors.size > 0
    end

    private

    def fail!(errors)
      emsg = "{ " + errors.map { |k, e| "#{k} => #{e}" }.join(", ") + " }"
      raise Membrane::SchemaValidationError.new(emsg)
    end
  end
end
