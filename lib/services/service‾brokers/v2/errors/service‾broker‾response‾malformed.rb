module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerResponseMalformed < HttpResponseError
          def initialize(uri, method, response, description)
            @uri = uri
            super(
              description_from_response(description),
              uri,
              method,
              response
            )
          end

          def response_code
            502
          end

          private

          def description_from_response(description)
            "The service broker returned an invalid response for the request to #{@uri}: #{description}"
          end
        end
      end
    end
  end
end
