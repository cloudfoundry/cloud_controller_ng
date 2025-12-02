require "membrane/errors"
require "membrane/schemas/base"

module Membrane
  module Schema
  end
end

class Membrane::Schemas::Tuple < Membrane::Schemas::Base
  attr_reader :elem_schemas

  def initialize(*elem_schemas)
    @elem_schemas = elem_schemas
  end

  def validate(object)
    ArrayValidator.new(object).validate
    LengthValidator.new(@elem_schemas, object).validate
    MemberValidator.new(@elem_schemas, object).validate

    nil
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

  class LengthValidator
    def initialize(elem_schemas, object)
      @elem_schemas = elem_schemas
      @object = object
    end

    def validate
      expected = @elem_schemas.length
      actual = @object.length

      fail!(expected, actual) if actual != expected
    end

    private

    def fail!(expected, actual)
      emsg = "Expected #{expected} element(s), given #{actual}"
      raise Membrane::SchemaValidationError.new(emsg)
    end
  end

  class MemberValidator
    def initialize(elem_schemas, object)
      @elem_schemas = elem_schemas
      @object = object
    end

    def validate
      errors = {}

      @elem_schemas.each_with_index do |schema, ii|
        begin
          schema.validate(@object[ii])
        rescue Membrane::SchemaValidationError => e
          errors[ii] = e
        end
      end

      fail!(errors) if errors.size > 0
    end

    private

    def fail!(errors)
      emsg = "There were errors at the following indices: " \
             + errors.map { |ii, err| "#{ii} => #{err}" }.join(", ")
      raise Membrane::SchemaValidationError.new(emsg)
    end
  end
end
