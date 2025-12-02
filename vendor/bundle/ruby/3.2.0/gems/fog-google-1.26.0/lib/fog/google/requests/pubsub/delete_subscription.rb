module Fog
  module Google
    class Pubsub
      class Real
        # Delete a subscription on the remote service.
        #
        # @param subscription_name [#to_s] name of subscription to delete
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions/delete
        def delete_subscription(subscription_name)
          @pubsub.delete_subscription(subscription_name)
        end
      end

      class Mock
        def delete_subscription(_subscription_name)
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
