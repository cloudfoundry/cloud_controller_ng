require 'net/http'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerApiTimeout < HttpRequestError
          def initialize(uri, method, source)
            super(
              "The service broker API timed out: #{uri}",
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
