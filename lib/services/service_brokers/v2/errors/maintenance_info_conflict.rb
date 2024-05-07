module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class MaintenanceInfoConflict < HttpResponseError
          def initialize(_uri, method, response)
            begin
              body = Oj.load(response.body)
            rescue StandardError
              # ignore
            end

            message = if body.is_a?(Hash) && valid_description?(body['description'])
                        "Service broker error: #{body['description']}"
                      else
                        'The service broker did not provide a reason for this conflict, please ensure the ' \
                          'catalog is up to date and you are providing a version supported by this service plan'
                      end

            super(message, method, response)
          end

          def response_code
            422
          end

          private

          def valid_description?(description)
            description.is_a?(String) && !description.strip.empty?
          end
        end
      end
    end
  end
end
