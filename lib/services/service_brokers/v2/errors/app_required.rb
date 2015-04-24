module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class AppRequired < HttpResponseError
          def initialize(uri, method, response)
            message = VCAP::Errors::ApiError.new_from_details('ServiceKeyNotCreatable').message
            super(message, uri, method, response)
          end

          def response_code
            400
          end
        end
      end
    end
  end
end
