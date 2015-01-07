module VCAP::Services
  module ServiceBrokers
    module V2
      class ResponseParser
        def initialize(url)
          @url = url
        end

        def parse(method, path, response)
          uri = uri_for(path)
          code = response.code.to_i

          case code
          when 204
            return nil # no body

          when 200..299

            begin
              response_hash = MultiJson.load(response.body)
            rescue MultiJson::ParseError
              logger.warn("MultiJson parse error `#{response.try(:body).inspect}'")
            end

            unless response_hash.is_a?(Hash)
              raise VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerResponseMalformed.new(uri.to_s, method, response)
            end

            return response_hash

          when HTTP::Status::UNAUTHORIZED
            raise VCAP::Services::ServiceBrokers::V2::ServiceBrokerApiAuthenticationFailed.new(uri.to_s, method, response)

          when 408
            raise VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerApiTimeout.new(uri.to_s, method, response)

          when 409
            raise VCAP::Services::ServiceBrokers::V2::ServiceBrokerConflict.new(uri.to_s, method, response)

          when 410
            if method == :delete
              logger.warn("Already deleted: #{uri}")
              return nil
            end
          end

          raise VCAP::Services::ServiceBrokers::V2::ServiceBrokerBadResponse.new(uri.to_s, method, response)
        end

        private

        def uri_for(path)
          URI(@url + path)
        end

        def logger
          @logger ||= Steno.logger('cc.service_broker.v2.client')
        end
      end
    end
  end
end
