module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerInvalidVolumeMounts < HttpResponseError
          def initialize(uri, method, response, description)
            super(
              description_from_response(description),
              method,
              response
            )
          end

          def response_code
            502
          end

          private

          def description_from_response(description)
            "The service broker returned an invalid response: #{description}"
          end
        end
      end
    end
  end
end
