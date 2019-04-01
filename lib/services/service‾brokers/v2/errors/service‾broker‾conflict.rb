module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerConflict < HttpResponseError
          def initialize(uri, method, response)
            error_message = nil
            parsed_response = parsed_json(response.body)
            if parsed_response.is_a?(Hash) && parsed_response.key?('description')
              error_description = parsed_json(response.body)['description']
              error_message = "Service broker error: #{error_description}"
            end

            super(
              error_message || "Resource conflict: #{uri}",
              uri,
              method,
              response
            )
          end

          def response_code
            409
          end

          private

          def parsed_json(str)
            MultiJson.load(str)
          rescue MultiJson::ParseError
            {}
          end
        end
      end
    end
  end
end
