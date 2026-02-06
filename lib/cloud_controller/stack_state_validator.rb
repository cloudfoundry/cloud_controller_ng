module VCAP::CloudController
  class StackStateValidator
    class StackValidationError < StandardError; end
    class DisabledStackError < StackValidationError; end
    class RestrictedStackError < StackValidationError; end
    def self.validate_for_new_app!(stack)
      return [] if stack.active?

      raise DisabledStackError.new(build_stack_error(stack, StackStates::STACK_DISABLED)) if stack.disabled?

      raise RestrictedStackError.new(build_stack_error(stack, StackStates::STACK_RESTRICTED)) if stack.restricted?

      stack.deprecated? ? [build_stack_warning(stack, StackStates::STACK_DEPRECATED)] : []
    end

    def self.validate_for_restaging!(stack)
      return [] if stack.active?

      return [build_stack_warning(stack, StackStates::STACK_RESTRICTED)] if stack.restricted?

      return [build_stack_warning(stack, StackStates::STACK_DEPRECATED)] if stack.deprecated?

      raise DisabledStackError.new(build_stack_error(stack, StackStates::STACK_DISABLED)) if stack.disabled?

      []
    end

    def self.build_stack_error(stack, state)
      message = "ERROR: Staging failed. The stack '#{stack.name}' is '#{state}' and cannot be used for staging."
      message += " #{stack.state_reason}" if stack.state_reason.present?
      message
    end

    def self.build_stack_warning(stack, state)
      message = "WARNING: The stack '#{stack.name}' is '#{state}' and will be removed in the future."
      message += " #{stack.state_reason}" if stack.state_reason.present?
      message
    end
  end
end
