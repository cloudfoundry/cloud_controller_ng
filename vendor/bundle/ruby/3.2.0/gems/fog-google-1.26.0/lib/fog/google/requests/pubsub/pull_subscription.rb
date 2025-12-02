module Fog
  module Google
    class Pubsub
      class Real
        # Pulls from a subscription. If option 'return_immediately' is
        # false, then this method blocks until one or more messages is
        # available or the remote server closes the connection.
        #
        # @param subscription [Subscription, #to_s] subscription instance or
        #   name of subscription to pull from
        # @param options [Hash] options to modify the pull request
        # @option options [Boolean] :return_immediately if true, method returns
        #   after API call; otherwise the connection is held open until
        #   messages are available or the remote server closes the connection
        #   (defaults to true)
        # @option options [Number] :max_messages maximum number of messages to
        #   retrieve (defaults to 10)
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.subscriptions/pull
        def pull_subscription(subscription, options = {})
          defaults = { :return_immediately => true,
                       :max_messages => 10 }
          options = defaults.merge(options)

          pull_request = ::Google::Apis::PubsubV1::PullRequest.new(
            :return_immediately => options[:return_immediately],
            :max_messages => options[:max_messages]
          )

          @pubsub.pull_subscription(subscription, pull_request)
        end
      end

      class Mock
        def pull_subscription(_subscription, _options = { :return_immediately => true, :max_messages => 10 })
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
