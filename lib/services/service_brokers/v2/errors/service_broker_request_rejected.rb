module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        class ServiceBrokerRequestRejected < HttpResponseError
          def initialize(uri, method, response)
            begin
              @hash = MultiJson.load(response.body)
            rescue MultiJson::ParseError
              @hash = {}
            end

            message = VCAP::Errors::ApiError.new_from_details('ServiceBrokerRequestRejected', uri, response.code, response.message).message
            if @hash.is_a?(Hash)
              if @hash['error'] == 'AsyncRequired'
                details = VCAP::Errors::Details.new(@hash['error'])
                message = details.message_format
              elsif !@hash.key?('error') && @hash.key?('description')
                message = VCAP::Errors::ApiError.new_from_details('ServiceBrokerRequestRejectedWithDescription', @hash['description']).message
              end
            end

            super(message, uri, method, response)
          end

          def parsed_response
            @hash
          end

          def response_code
            502
          end
        end
      end
    end
  end
end
