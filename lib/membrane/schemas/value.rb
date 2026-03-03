require "membrane/errors"
require "membrane/schemas/base"

module Membrane
  module Schema
  end
end

class Membrane::Schemas::Value < Membrane::Schemas::Base
  attr_reader :value

  def initialize(value)
    @value = value
  end

  def validate(object)
    ValueValidator.new(@value, object).validate
  end

  class ValueValidator
    def initialize(value, object)
      @value = value
      @object = object
    end

    def validate
      fail!(@value, @object) if @object != @value
    end

    private

    def fail!(expected, given)
      emsg = "Expected #{expected}, given #{given}"
      raise Membrane::SchemaValidationError.new(emsg)
    end
  end
end
