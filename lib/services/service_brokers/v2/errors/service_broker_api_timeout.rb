require 'net/http'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerApiTimeout < HttpRequestError
          def initialize(uri, method, source)
            super(
              "The request to the service broker timed out: #{uri}",
              uri,
              method,
              source
            )
          end

          def response_code
            504
          end
        end
      end
    end
  end
end
