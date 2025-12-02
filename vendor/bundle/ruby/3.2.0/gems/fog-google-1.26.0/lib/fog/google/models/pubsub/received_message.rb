require "fog/core/model"

module Fog
  module Google
    class Pubsub
      # Represents a ReceivedMessage retrieved from a Google Pubsub
      # subscription. Note that ReceivedMessages are immutable.
      #
      # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions/pull#ReceivedMessage
      class ReceivedMessage < Fog::Model
        identity :ack_id, :aliases => "ackId"

        attribute :message

        def initialize(new_attributes = {})
          # Here we secretly store the subscription name we were received on
          # in order to support #acknowledge
          attributes = new_attributes.clone
          @subscription_name = attributes.delete(:subscription_name)
          super(attributes)
        end

        # Acknowledges a message.
        #
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions/acknowledge
        def acknowledge
          requires :ack_id

          service.acknowledge_subscription(@subscription_name, [ack_id])
          nil
        end

        def reload
          # Message is immutable - do nothing
          Fog::Logger.warning("#reload called on immutable ReceivedMessage")
        end
      end
    end
  end
end
