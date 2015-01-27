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

          begin
            response_hash = MultiJson.load(response.body)
          rescue MultiJson::ParseError
            logger.warn("MultiJson parse error `#{response.try(:body).inspect}'")
          end

          case code
          when 204
            return nil # no body

          when 200..299
            unless response_hash.is_a?(Hash)
              raise Errors::ServiceBrokerResponseMalformed.new(uri.to_s, method, sanitize_response(response))
            end

            if !valid_broker_response?(method, path, code, response_hash['state'])
              raise Errors::ServiceBrokerBadResponse.new(uri.to_s, method, sanitize_response(response))
            end

            return response_hash

          when HTTP::Status::UNAUTHORIZED
            raise Errors::ServiceBrokerApiAuthenticationFailed.new(uri.to_s, method, response)

          when 408
            raise Errors::ServiceBrokerApiTimeout.new(uri.to_s, method, response)

          when 409
            raise Errors::ServiceBrokerConflict.new(uri.to_s, method, response)

          when 410
            if method == :delete
              logger.warn("Already deleted: #{uri}")
              return nil
            end

          when 400..499
            raise Errors::ServiceBrokerRequestRejected.new(uri.to_s, method, response)
          end

          raise Errors::ServiceBrokerBadResponse.new(uri.to_s, method, response)
        end

        # Move these to ValidateBrokerResponse class when we do update and delete
        def valid_broker_response?(method, path, code, state)
          return true if ![:put, :get].include?(method) || !%r{/v2/service_instances/.+}.match(path)

          return true if code == 200 && ['in progress', 'succeeded', 'failed', nil].include?(state)

          return true if code == 201 && (state == 'succeeded' || state.nil?)
          return true if code == 202 && state == 'in progress'

          false
        end

        private

        def sanitize_response(response)
          HttpResponse.new(
            code: response.code,
            message: response.message,
            body: "\"#{response.body}\""
          )
        end

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
