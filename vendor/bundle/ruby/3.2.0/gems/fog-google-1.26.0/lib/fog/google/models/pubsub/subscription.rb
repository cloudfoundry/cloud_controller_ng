module Fog
  module Google
    class Pubsub
      # Represents a Pubsub subscription resource
      #
      # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions
      class Subscription < Fog::Model
        identity :name
        attribute :topic
        attribute :push_config, :aliases => "pushConfig"
        attribute :ack_deadline_seconds, :aliases => "ackDeadlineSeconds"

        # Pulls from this subscription, returning any available messages. By
        # default, this method returns immediately with up to 10 messages. The
        # option 'return_immediately' allows the method to block until a
        # message is received, or the remote service closes the connection.
        #
        # Note that this method automatically performs a base64 decode on the
        # 'data' field.
        #
        # @param options [Hash] options to modify the pull request
        # @option options [Boolean] :return_immediately If true, method returns
        #   after checking for messages. Otherwise the method blocks until one
        #   or more messages are available, or the connection is closed.
        # @option options [Number] :max_messages maximum number of messages to
        #   receive
        # @return [Array<Fog::Google::Pubsub::ReceivedMessage>] list of
        #   received messages, or an empty list if no messages are available.
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions/pull
        def pull(options = { :return_immediately => true, :max_messages => 10 })
          requires :name

          data = service.pull_subscription(name, options).to_h

          return [] unless data.key?(:received_messages)
          # Turn into a list of ReceivedMessage, but ensure we perform a base64 decode first
          data[:received_messages].map do |recv_message|
            attrs = {
              :service => service,
              :subscription_name => name
            }.merge(recv_message)

            attrs[:message][:data] = Base64.decode64(recv_message[:message][:data]) if recv_message[:message].key?(:data)
            ReceivedMessage.new(attrs)
          end
        end

        # Acknowledges a list of received messages for this subscription.
        #
        # @param messages [Array<Fog::Google::Pubsub::ReceivedMessage, #to_s>]
        #   A list containing either ReceivedMessage instances to acknowledge,
        #   or a list of ackIds (@see
        #   https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions/pull#ReceivedMessage).
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions/acknowledge
        def acknowledge(messages)
          return if messages.empty?

          ack_ids = messages.map { |m| m.is_a?(ReceivedMessage) ? m.ack_id : m.to_s }

          service.acknowledge_subscription(name, ack_ids)
          nil
        end

        # Save this instance on the remove service.
        #
        # @return [Fog::Google::Pubsub::Subscription] this instance
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions/create
        def save
          requires :name, :topic

          data = service.create_subscription(name, topic, push_config, ack_deadline_seconds).to_h
          merge_attributes(data)
        end

        # Deletes this subscription on the remote service.
        #
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions/delete
        def destroy
          requires :name

          service.delete_subscription(name)
        end
      end
    end
  end
end
