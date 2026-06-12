require 'utils/uri_utils'

module VCAP::CloudController
  module Diego
    # Custom stacks reuse the default stack's lifecycle binaries.
    module CustomStackFallback
      def resolved_stack_name(stack=nil)
        stack ||= @stack || (respond_to?(:lifecycle_stack, true) ? lifecycle_stack : nil)
        UriUtils.is_custom_stack_uri?(stack) ? VCAP::CloudController::Stack.default.name : stack
      end
    end
  end
end
