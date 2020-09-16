require 'cloud_controller/http_response_error'

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

            message = if hash.is_a?(Hash) && hash.key?('description') && !ignore_description_key
                        "Service broker error: #{hash['description']}"
                      else
                        'The service broker returned an invalid response. ' \
                                  "Status Code: #{response.code} #{response.message}, Body: #{response.body}"
                      end

            super(message, method, response)
          end

          def response_code
            502
          end

          def to_h
            hash = super
            hash['http'] = {
              'method' => method,
              'status' => status,
            }
            hash
          end
        end
      end
    end
  end
end
