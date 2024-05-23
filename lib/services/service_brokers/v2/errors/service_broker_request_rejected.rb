module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerRequestRejected < HttpResponseError
          def initialize(_uri, method, response)
            begin
              hash = Oj.load(response.body)
            rescue StandardError
              # ignore
            end

            message = if hash.is_a?(Hash) && hash.key?('description')
                        "Service broker error: #{hash['description']}"
                      else
                        "The service broker rejected the request. Status Code: #{response.code} #{response.message}, Body: #{response.body}"
                      end

            super(message, method, response)
          end

          def response_code
            502
          end
        end
      end
    end
  end
end
