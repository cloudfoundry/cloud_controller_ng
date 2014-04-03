module VCAP::Services
  class ValidationErrors
    attr_reader :messages, :nested_errors

    def initialize
      @messages = []
      @nested_errors = {}
    end

    def add(message)
      messages << message
      self
    end

    def add_nested(object_with_errors, validation_errors=ValidationErrors.new)
      nested_errors[object_with_errors] ||= validation_errors
    end

    def empty?
      messages.empty? && nested_errors.values.all?(&:empty?)
    end

    def for(object_with_errors)
      nested_errors[object_with_errors]
    end
  end
end
