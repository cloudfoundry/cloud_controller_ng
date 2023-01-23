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
              if error_message.bytesize > 2**14
                error_message = error_message.truncate_bytes(2**13) + "...This message has been truncated due to size. To read the full message, check the broker's logs"
              end
            end

            super(
              error_message || 'Resource conflict',
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
