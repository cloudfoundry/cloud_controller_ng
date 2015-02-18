module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerApiAuthenticationFailed < HttpResponseError
          def initialize(uri, method, response)
            super(
              "Authentication with the service broker failed. Double-check that the username and password are correct: #{uri}",
              uri,
              method,
              response
            )
          end

          def response_code
            502
          end
        end
      end
    end
  end
end
