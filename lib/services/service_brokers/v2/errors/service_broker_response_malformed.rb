module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerResponseMalformed < HttpResponseError
          def initialize(uri, method, response)
            super(
              'The service broker response was not understood',
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
