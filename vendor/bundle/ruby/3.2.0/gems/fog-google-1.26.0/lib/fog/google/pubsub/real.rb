module Fog
  module Google
    class Pubsub
      class Real
        include Fog::Google::Shared

        attr_accessor :client
        attr_reader :pubsub

        def initialize(options)
          shared_initialize(options[:google_project], GOOGLE_PUBSUB_API_VERSION, GOOGLE_PUBSUB_BASE_URL)
          options[:google_api_scope_url] = GOOGLE_PUBSUB_API_SCOPE_URLS.join(" ")

          @client = initialize_google_client(options)
          @pubsub = ::Google::Apis::PubsubV1::PubsubService.new
          apply_client_options(@pubsub, options)
        end
      end
    end
  end
end
