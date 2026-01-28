module VCAP::CloudController
  class StackStateValidator
    class StackValidationError < StandardError; end
    class DisabledStackError < StackValidationError; end
    class RestrictedStackError < StackValidationError; end
    def self.validate_for_new_app!(stack)
      return [] if stack.active?

      raise DisabledStackError.new(build_stack_error(stack, StackStates::STACK_DISABLED)) if stack.disabled?

      raise RestrictedStackError.new(build_stack_error(stack, StackStates::STACK_RESTRICTED)) if stack.restricted?

      stack.deprecated? ? [build_deprecation_warning(stack, StackStates::STACK_DEPRECATED)] : []
    end

    def self.validate_for_restaging!(stack)
      return [] if stack.active? || stack.restricted?

      raise DisabledStackError.new(build_stack_error(stack, StackStates::STACK_DISABLED)) if stack.disabled?

      stack.deprecated? ? [build_deprecation_warning(stack, StackStates::STACK_DEPRECATED)] : []
    end

    def self.build_stack_error(stack, state)
      "ERROR: Staging failed. The stack '#{stack.name}' is '#{state}' and cannot be used for staging."
    end

    def self.build_deprecation_warning(stack, state)
      "WARNING: The stack '#{stack.name}' is '#{state}' and will be removed in the future."
    end
  end
end
