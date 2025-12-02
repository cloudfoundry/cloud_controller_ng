module Fog
  module Google
    class Pubsub
      class Real
        # Delete a topic on the remote service.
        #
        # @param topic_name [#to_s] name of topic to delete
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.topics/delete
        def delete_topic(topic_name)
          @pubsub.delete_topic(topic_name)
        end
      end

      class Mock
        def delete_topic(_topic_name)
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
