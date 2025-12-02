module Fog
  module Google
    class Pubsub
      class Real
        # Acknowledges a message received from a subscription.
        #
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions/acknowledge
        def acknowledge_subscription(subscription, ack_ids)
          # Previous behavior allowed passing a single ack_id without being wrapped in an Array,
          # this is for backwards compatibility.
          unless ack_ids.is_a?(Array)
            ack_ids = [ack_ids]
          end
          ack_request = ::Google::Apis::PubsubV1::AcknowledgeRequest.new(
            ack_ids: ack_ids
          )

          @pubsub.acknowledge_subscription(subscription, ack_request)
        end
      end

      class Mock
        def acknowledge_subscription(_subscription, _ack_ids)
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
