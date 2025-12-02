module Fog
  module Google
    class Pubsub
      class Real
        # Create a topic on the remote service.
        #
        # @param topic_name [#to_s] name of topic to create; note that it must
        #   obey the naming rules for a topic (e.g.
        #   'projects/myProject/topics/my_topic')
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.topics/create
        def create_topic(topic_name)
          @pubsub.create_topic(topic_name)
        end
      end

      class Mock
        def create_topic(_topic_name)
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
