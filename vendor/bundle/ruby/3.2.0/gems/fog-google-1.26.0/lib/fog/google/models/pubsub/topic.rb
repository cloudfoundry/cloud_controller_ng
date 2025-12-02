require "fog/core/model"

module Fog
  module Google
    class Pubsub
      # Represents a Pubsub topic resource
      #
      # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.topics#Topic
      class Topic < Fog::Model
        identity :name

        # Creates this topic resource on the service.
        #
        # @return [Fog::Google::Pubsub::Topic] this instance
        def create
          requires :name

          service.create_topic(name)
          self
        end

        # Deletes this topic resource on the service.
        #
        # @return [Fog::Google::Pubsub::Topic] this instance
        def destroy
          requires :name

          service.delete_topic(name)
          self
        end

        # Publish a message to this topic. This method will automatically
        # encode the message via base64 encoding.
        #
        # @param messages [Array<Hash{String => String}, #to_s>] list of messages
        #   to send; if it's a hash, then the value of key "data" will be sent
        #   as the message. Additionally, if the hash contains a value for key
        #   "attributes", then they will be sent as well as attributes on the
        #   message.
        # @return [Array<String>] list of message ids
        def publish(messages)
          requires :name

          # Ensure our messages are base64 encoded
          encoded_messages = []

          messages.each do |message|
            encoded_message = {}
            if message.is_a?(Hash)
              if message.key?("data")
                encoded_message[:data] = Base64.strict_encode64(message["data"])
              end
            else
              encoded_message[:data] = Base64.strict_encode64(message.to_s)
            end

            encoded_messages << encoded_message
          end

          service.publish_topic(name, encoded_messages).to_h[:message_ids]
        end

        # Save the instance (does the same thing as #create)
        # @return [Fog::Google::Pubsub::Topic] this instance
        def save
          create
        end
      end
    end
  end
end
