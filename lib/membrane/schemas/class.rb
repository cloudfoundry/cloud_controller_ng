require "membrane/errors"
require "membrane/schemas/base"

class Membrane::Schemas::Class < Membrane::Schemas::Base
  attr_reader :klass

  def initialize(klass)
    @klass = klass
  end

  # Validates whether or not the supplied object is derived from klass
  def validate(object)
    ClassValidator.new(@klass, object).validate
  end

  class ClassValidator

    def initialize(klass, object)
      @klass = klass
      @object = object
    end

    def validate
      fail!(@klass, @object) if !@object.kind_of?(@klass)
    end

    private

    def fail!(klass, object)
      emsg = "Expected instance of #{klass}," \
             + " given an instance of #{object.class}"
      raise Membrane::SchemaValidationError.new(emsg)
    end
  end
end
