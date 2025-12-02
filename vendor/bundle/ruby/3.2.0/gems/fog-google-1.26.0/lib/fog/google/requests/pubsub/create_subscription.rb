module Fog
  module Google
    class Pubsub
      class Real
        # Create a subscription resource on a topic.
        #
        # @param subscription_name [#to_s] name of the subscription to create.
        #   Note that it must follow the restrictions of subscription names;
        #   specifically it must be named within a project (e.g.
        #   "projects/my-project/subscriptions/my-subscripton")
        # @param topic [Topic, #to_s] topic instance or name of topic to create
        #   subscription on
        # @param push_config [Hash] configuration for a push config (if empty
        #   hash, then no push_config is created)
        # @param ack_deadline_seconds [Number] how long the service waits for
        #   an acknowledgement before redelivering the message; if nil then
        #   service default of 10 is used
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions/create
        def create_subscription(subscription_name, topic, push_config = {}, ack_deadline_seconds = nil)
          subscription = ::Google::Apis::PubsubV1::Subscription.new(
            topic: topic,
            ack_deadline_seconds: ack_deadline_seconds,
            push_config: push_config
          )

          @pubsub.create_subscription(subscription_name, subscription)
        end
      end

      class Mock
        def create_subscription(_subscription_name, _topic, _push_config = {}, _ack_deadline_seconds = nil)
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
