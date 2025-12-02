require "fog/core/collection"
require "fog/google/models/pubsub/subscription"

module Fog
  module Google
    class Pubsub
      class Subscriptions < Fog::Collection
        model Fog::Google::Pubsub::Subscription

        # Lists all subscriptions that exist on the project.
        #
        # @return [Array<Fog::Google::Pubsub::Subscription>] list of
        #   subscriptions
        def all
          data = service.list_subscriptions.to_h[:subscriptions] || []
          load(data)
        end

        # Retrieves a subscription by name
        #
        # @param subscription_name [String] name of subscription to retrieve
        # @return [Fog::Google::Pubsub::Topic] topic found, or nil if not found
        def get(subscription_name)
          subscription = service.get_subscription(subscription_name).to_h
          new(subscription)
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
