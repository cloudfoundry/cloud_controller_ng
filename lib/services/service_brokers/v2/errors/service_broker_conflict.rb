module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerConflict < HttpResponseError
          def initialize(uri, method, response)
            error_message = nil
            if parsed_json(response.body).key?('description')
              error_message = parsed_json(response.body)['description']
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
