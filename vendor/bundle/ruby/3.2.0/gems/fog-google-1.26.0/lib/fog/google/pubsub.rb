module Fog
  module Google
    class Pubsub < Fog::Service
      autoload :Mock, File.expand_path("../pubsub/mock", __FILE__)
      autoload :Real, File.expand_path("../pubsub/real", __FILE__)

      requires :google_project
      recognizes(
        :app_name,
        :app_version,
        :google_application_default,
        :google_auth,
        :google_client,
        :google_client_options,
        :google_json_key_location,
        :google_json_key_string,
        :google_key_location,
        :google_key_string
      )

      GOOGLE_PUBSUB_API_VERSION    = "v1".freeze
      GOOGLE_PUBSUB_BASE_URL       = "https://www.googleapis.com/pubsub".freeze
      GOOGLE_PUBSUB_API_SCOPE_URLS = %w(https://www.googleapis.com/auth/pubsub).freeze

      ##
      # MODELS
      model_path "fog/google/models/pubsub"

      # Topic
      model :topic
      collection :topics

      # Subscription
      model :subscription
      collection :subscriptions

      # ReceivedMessage
      model :received_message

      ##
      # REQUESTS
      request_path "fog/google/requests/pubsub"

      # Topic
      request :list_topics
      request :get_topic
      request :create_topic
      request :delete_topic
      request :publish_topic

      # Subscription
      request :list_subscriptions
      request :get_subscription
      request :create_subscription
      request :delete_subscription
      request :pull_subscription
      request :acknowledge_subscription

      # Helper class for getting a subscription name
      #
      # @param subscription [Subscription, #to_s] subscription instance or name
      #   of subscription
      # @return [String] name of subscription
      def self.subscription_name(subscription)
        subscription.is_a?(Subscription) ? subscription.name : subscription.to_s
      end
    end
  end
end
