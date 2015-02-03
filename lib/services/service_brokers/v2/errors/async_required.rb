module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class AsyncRequired < HttpResponseError
          def initialize(uri, method, response)
            message = 'This service plan requires client support for asynchronous provisioning.'
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
