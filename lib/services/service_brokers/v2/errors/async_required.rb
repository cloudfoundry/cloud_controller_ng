module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class AsyncRequired < HttpResponseError
          def initialize(uri, method, response)
            message = CloudController::Errors::ApiError.new_from_details('ServiceBrokerAsyncRequired').message
            super(message, uri, method, response)
          end

          def response_code
            400
          end
        end
      end
    end
  end
end
