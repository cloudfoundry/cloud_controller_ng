module VCAP::CloudController
  class StackStateValidator
    class StackValidationError < StandardError; end
    class DisabledStackError < StackValidationError; end
    class RestrictedStackError < StackValidationError; end
    def self.validate_for_new_app!(stack)
      return [] if stack.active?

      raise DisabledStackError.new("Stack '#{stack.name}' is disabled and cannot be used for staging new applications. #{stack.description}") if stack.disabled?

      raise RestrictedStackError.new("Stack '#{stack.name}' is restricted and cannot be used for staging new applications. #{stack.description}") if stack.restricted?

      stack.deprecated? ? [build_deprecation_warning(stack)] : []
    end

    def self.validate_for_restaging!(stack)
      return [] if stack.active? || stack.restricted?

      raise DisabledStackError.new("Stack '#{stack.name}' is disabled and cannot be used for staging new applications. #{stack.description}") if stack.disabled?

      stack.deprecated? ? [build_deprecation_warning(stack)] : []
    end

    def self.build_deprecation_warning(stack)
      "Stack '#{stack.name}' is deprecated and will be removed in the future. #{stack.description}"
    end
  end
end
