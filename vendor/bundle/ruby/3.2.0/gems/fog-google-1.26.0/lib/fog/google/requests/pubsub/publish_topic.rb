module Fog
  module Google
    class Pubsub
      class Real
        # Publish a list of messages to a topic.
        #
        # @param messages [Array<Hash>] List of messages to be published to a
        #   topic; each hash should have a value defined for 'data' or for
        #   'attributes' (or both). Note that the value associated with 'data'
        #   must be base64 encoded.
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.topics/publish
        def publish_topic(topic, messages)
          publish_request = ::Google::Apis::PubsubV1::PublishRequest.new(
            :messages => messages
          )

          @pubsub.publish_topic(topic, publish_request)
        end
      end

      class Mock
        def publish_topic(_topic, _messages)
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
