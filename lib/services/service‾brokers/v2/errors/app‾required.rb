module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class AppRequired < HttpResponseError
          def initialize(uri, method, response)
            message = 'This service supports generation of credentials through binding an application only.'
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
