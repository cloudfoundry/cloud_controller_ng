module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ConcurrencyError < HttpResponseError
          def initialize(uri, method, response)
            message = CloudController::Errors::ApiError.new_from_details('ServiceBrokerConcurrencyError').message
            super(message, method, response)
          end

          def response_code
            422
          end
        end
      end
    end
  end
end
