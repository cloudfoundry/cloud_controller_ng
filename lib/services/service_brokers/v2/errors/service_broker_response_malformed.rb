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
        end
      end
    end
  end
end
