module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerBadResponse < HttpResponseError
          def initialize(uri, method, response, ignore_description_key: false)
            begin
              hash = MultiJson.load(response.body)
            rescue MultiJson::ParseError
            end

            if hash.is_a?(Hash) && hash.key?('description') && !ignore_description_key
              message = "Service broker error: #{hash['description']}"
            else
              message = "The service broker returned an invalid response for the request to #{uri}. " \
                        "Status Code: #{response.code} #{response.message}, Body: #{response.body}"
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
