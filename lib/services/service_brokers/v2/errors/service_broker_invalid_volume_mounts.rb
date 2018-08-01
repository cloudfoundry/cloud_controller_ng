module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerInvalidVolumeMounts < HttpResponseError
          def initialize(uri, method, response, description)
            super(
              description_from_response(uri, description),
              uri,
              method,
              response
            )
          end

          def response_code
            502
          end

          private

          def description_from_response(uri, description)
            "The service broker returned an invalid response for the request to #{uri}: #{description}"
          end
        end
      end
    end
  end
end
