require "fog/core/collection"
require "fog/google/models/pubsub/topic"

module Fog
  module Google
    class Pubsub
      class Topics < Fog::Collection
        model Fog::Google::Pubsub::Topic

        # Lists all topics that exist on the project.
        #
        # @return [Array<Fog::Google::Pubsub::Topic>] list of topics
        def all
          data = service.list_topics.to_h[:topics] || []
          load(data)
        end

        # Retrieves a topic by name
        #
        # @param topic_name [String] name of topic to retrieve
        # @return [Fog::Google::Pubsub::Topic] topic found, or nil if not found
        def get(topic_name)
          topic = service.get_topic(topic_name).to_h
          new(topic)
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
