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

          raise_for_common_errors(code, uri, method, response)

          case method
          when :put
            return parse_put_response(code, uri, response)
          when :delete
            return parse_delete_response(code, uri, response)
          when :get
            return parse_get_response(code, uri, response)
          when :patch
            return parse_patch_response(code, uri, response)
          end
        end

        private

        def parse_get_response(code, uri, response)
          parsed_response = parse_response(uri, :get, response)
          state = state_from_parsed_response(parsed_response)
          case code
          when 200
            raise_if_malformed_response(uri, :get, response, parsed_response)
            return parsed_response if recogized_operation_state?(state)
            raise Errors::ServiceBrokerResponseMalformed.new(uri.to_s, :get, response)
          else
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :get, response)
          end
        end

        def parse_put_response(code, uri, response)
          parsed_response = parse_response(uri, :put, response)
          if request_for_bindings?(uri) && parsed_response
            parsed_response.except!('last_operation')
          end
          state = state_from_parsed_response(parsed_response)

          handle_put_non_success(code, uri, response, parsed_response)

          case code
          when 200
            raise_if_malformed_response(uri, :put, response, parsed_response)
            return parsed_response if recogized_operation_state?(state)
          when 201
            raise_if_malformed_response(uri, :put, response, parsed_response)
            return parsed_response if ['succeeded', nil].include?(state)
          when 202
            raise_if_malformed_response(uri, :put, response, parsed_response)
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :put, response) if request_for_bindings?(uri)
            return parsed_response if state == 'in progress'
          end

          raise Errors::ServiceBrokerResponseMalformed.new(uri.to_s, :put, response)
        end

        def handle_put_non_success(code, uri, response, parsed_response)
          case code
          when 200, 201, 202
            return
          when 409
            raise Errors::ServiceBrokerConflict.new(uri.to_s, :put, response)
          when 422
            raise Errors::AsyncRequired.new(uri.to_s, :put, response) if is_async_required? parsed_response
          end

          raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :put, response)
        end

        def parse_patch_response(code, uri, response)
          parsed_response = parse_response(uri, :patch, response)
          case code
          when 200, 202
            raise_if_malformed_response(uri, :get, response, parsed_response)
            return parsed_response
          when 422
            raise Errors::ServiceBrokerRequestRejected.new(uri.to_s, :patch, response)
          else
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :patch, response)
          end
        end

        def parse_delete_response(code, uri, response)
          parsed_response = parse_response(uri, :delete, response)
          case code
          when 200
            raise_if_malformed_response(uri, :get, response, parsed_response)
            return parsed_response
          when 410
            logger.warn("Already deleted: #{uri}")
            return nil
          else
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :delete, response)
          end
        end

        def state_from_parsed_response(parsed_response)
          parsed_response ||= {}
          last_operation = parsed_response['last_operation'] || {}
          last_operation['state']
        end

        def parse_response(uri, method, response)
          begin
            parsed_response = MultiJson.load(response.body)
          rescue MultiJson::ParseError
            logger.warn("MultiJson parse error `#{response.try(:body).inspect}'")
          end

          return nil unless parsed_response.is_a?(Hash)

          parsed_response
        end

        def raise_if_malformed_response(uri, method, response, parsed_response)
          unless parsed_response
            raise Errors::ServiceBrokerResponseMalformed.new(uri, method, sanitize_response(response))
          end
        end

        def raise_for_common_errors(code, uri, method, response)
          case code
          when 401
            raise Errors::ServiceBrokerApiAuthenticationFailed.new(uri.to_s, method, response)
          when 408
            raise Errors::ServiceBrokerApiTimeout.new(uri.to_s, method, response)
          when 409, 410, 422
            return nil
          when 400..499
            raise Errors::ServiceBrokerRequestRejected.new(uri.to_s, method, response)
          when 500..599
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, method, response)
          end
        end

        def is_async_required?(parsed_response)
          parsed_response.is_a?(Hash) && parsed_response['error'] == 'AsyncRequired'
        end

        def request_for_bindings?(uri)
          !!%r{/v2/service_instances/[[:alnum:]-]+/service_bindings}.match(uri.to_s)
        end

        def recogized_operation_state?(state)
          ['succeeded', 'failed', 'in progress', nil].include?(state)
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
