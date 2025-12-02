module Fog
  module Google
    class Pubsub
      class Real
        # Retrieves a subscription by name from the remote service.
        #
        # @param subscription_name [#to_s] name of subscription to retrieve
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.topics/get
        def get_subscription(subscription_name)
          @pubsub.get_subscription(subscription_name)
        end
      end

      class Mock
        def get_subscription(_subscription_name)
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
