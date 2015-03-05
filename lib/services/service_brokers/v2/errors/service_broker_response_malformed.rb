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
            begin
              hash = MultiJson.load(response.body)
            rescue MultiJson::ParseError
            end

            if hash.is_a?(Hash) && hash.key?('last_operation')
              "The service broker response was not understood: expected state was 'succeeded', broker returned '#{hash['last_operation']['state']}'"
            else
              "The service broker response was not understood: expected valid JSON object in body, broker returned '#{response.body}'"
            end
          end
        end
      end
    end
  end
end
