module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerRequestRejected < HttpResponseError
          def initialize(uri, method, response)
            begin
              hash = MultiJson.load(response.body)
            rescue MultiJson::ParseError
            end

            message = if hash.is_a?(Hash) && hash.key?('description')
                        "Service broker error: #{hash['description']}"
                      else
                        "The service broker rejected the request to #{uri}. Status Code: #{response.code} #{response.message}, Body: #{response.body}"
                      end

            super(message, uri, method, response)
          end

          def response_code
            502
          end
        end
      end
    end
  end
end
