module VCAP::Services
  module ServiceBrokers
    module V2
      class ResponseParser
        def initialize(url)
          @url = url
        end

        def parse(method, path, response)
          code = response.code.to_i
          uri = uri_for(path)

          case code
          when 200..299
            return handle_success_response(method, path, uri, response)
          when 400..499
            return handle_error_response(method, path, uri, response)
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

        def parse_response(response)
          MultiJson.load(response.body)
        rescue MultiJson::ParseError
          logger.warn("MultiJson parse error `#{response.try(:body).inspect}'")
        end

        def handle_success_response(method, path, uri, response)
          response_hash = parse_response(response)
          code = response.code.to_i
          if code == 204
            # Matching only /v2/service_instances/:guid paths
            if %r{/v2/service_instances/[[:alnum:]-]+\z}.match(path)
              raise Errors::ServiceBrokerResponseMalformed.new(uri.to_s, method, response)
            end
            nil
          else
            unless response_hash.is_a?(Hash)
              raise Errors::ServiceBrokerResponseMalformed.new(uri.to_s, method, sanitize_response(response))
            end

            if !valid_broker_response?(method, path, code, response_hash['state'])
              raise Errors::ServiceBrokerBadResponse.new(uri.to_s, method, sanitize_response(response))
            end

            response_hash
          end
        end

        def handle_error_response(method, path, uri, response)
          code = response.code.to_i
          case code
          when 401
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
