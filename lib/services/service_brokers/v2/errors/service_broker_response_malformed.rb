module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerResponseMalformed < HttpResponseError
          def initialize(uri, method, response, description=nil)
            super(
              description || description_from_response(response),
              uri,
              method,
              response
            )
          end

          def response_code
            502
          end

          private

          def description_from_response(response)
            "The service broker response was not understood: expected valid JSON object in body, broker returned '#{response.body}'"
          end
        end
      end
    end
  end
end
