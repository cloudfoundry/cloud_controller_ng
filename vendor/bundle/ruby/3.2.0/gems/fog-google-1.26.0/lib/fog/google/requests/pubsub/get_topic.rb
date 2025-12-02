module Fog
  module Google
    class Pubsub
      class Real
        # Retrieves a resource describing a topic.
        #
        # @param topic_name [#to_s] name of topic to retrieve
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.topics/get
        def get_topic(topic_name)
          @pubsub.get_topic(topic_name)
        end
      end

      class Mock
        def get_topic(_topic_name)
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
