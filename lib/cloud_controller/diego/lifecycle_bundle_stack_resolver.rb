require 'utils/uri_utils'

module VCAP::CloudController
  module Diego
    # Selects the installed stack used to obtain lifecycle bundles and droplet destinations.
    # A custom stack remains the Diego rootfs; it uses the default stack only for these assets.
    class LifecycleBundleStackResolver
      def self.resolve(stack)
        UriUtils.is_custom_stack_uri?(stack) ? VCAP::CloudController::Stack.default.name : stack
      end
    end
  end
end
