module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerInvalidSyslogDrainUrl < HttpResponseError
          def initialize(uri, method, response)
            super(
              'The service is attempting to stream logs from your application, but is not registered as a logging service. Please contact the service provider.',
              uri,
              method,
              response
            )
          end

          def response_code
            502
          end
        end
      end
    end
  end
end
