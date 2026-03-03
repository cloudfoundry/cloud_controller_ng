require "membrane/errors"
require "membrane/schemas/base"

module Membrane
  module Schema
  end
end

class Membrane::Schemas::List < Membrane::Schemas::Base
  attr_reader :elem_schema

  def initialize(elem_schema)
    @elem_schema = elem_schema
  end

  def validate(object)
    ArrayValidator.new(object).validate
    MemberValidator.new(@elem_schema, object).validate
  end

  class ArrayValidator
    def initialize(object)
      @object = object
    end

    def validate
      fail!(@object) if !@object.kind_of?(Array)
    end

    private

    def fail!(object)
      emsg = "Expected instance of Array, given instance of #{object.class}"
      raise Membrane::SchemaValidationError.new(emsg)
    end
  end

  class MemberValidator
    def initialize(elem_schema, object)
      @elem_schema = elem_schema
      @object = object
    end

    def validate
      errors = {}

      @object.each_with_index do |elem, ii|
        begin
          @elem_schema.validate(elem)
        rescue Membrane::SchemaValidationError => e
          errors[ii] = e.to_s
        end
      end

      fail!(errors) if errors.size > 0
    end

    def fail!(errors)
      emsg = errors.map { |ii, e| "At index #{ii}: #{e}" }.join(", ")
      raise Membrane::SchemaValidationError.new(emsg)
    end
  end
end
