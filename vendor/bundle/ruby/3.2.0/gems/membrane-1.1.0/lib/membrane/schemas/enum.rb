require "membrane/errors"
require "membrane/schemas/base"

module Membrane
  module Schema
  end
end

class Membrane::Schemas::Enum < Membrane::Schemas::Base
  attr_reader :elem_schemas

  def initialize(*elem_schemas)
    @elem_schemas = elem_schemas
  end

  def validate(object)
    EnumValidator.new(@elem_schemas, object).validate
  end

  class EnumValidator
    def initialize(elem_schemas, object)
      @elem_schemas = elem_schemas
      @object = object
    end

    def validate
      @elem_schemas.each do |schema|
        begin
          schema.validate(@object)
          return nil
        rescue Membrane::SchemaValidationError
        end
      end

      fail!(@elem_schemas, @object)
    end

    private

    def fail!(elem_schemas, object)
      elem_schema_str = elem_schemas.map { |s| s.to_s }.join(", ")

      emsg = "Object #{object} doesn't validate" \
           + " against any of #{elem_schema_str}"
      raise Membrane::SchemaValidationError.new(emsg)
    end
  end

end
