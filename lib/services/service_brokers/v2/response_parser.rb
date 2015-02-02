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

        def parse_get_response(code, uri, response)
          response_hash = parse_response(uri, :get, response)
          state = state_from_response_hash(response_hash)
          case code
          when 200
            return response_hash if recogized_operation_state?(state)
            raise Errors::ServiceBrokerResponseMalformed.new(uri.to_s, :get, response)
          else
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :get, response)
          end
        end

        def parse_put_response(code, uri, response)
          response_hash = parse_response(uri, :put, response)
          state = state_from_response_hash(response_hash)

          case code
          when 200
            response_hash.except!('last_operation') if request_for_bindings?(uri)
            return response_hash if recogized_operation_state?(state)
            raise Errors::ServiceBrokerResponseMalformed.new(uri.to_s, :put, response)
          when 201
            if request_for_bindings?(uri)
              response_hash.except!('last_operation')
              return response_hash
            end
            return response_hash if ['succeeded', nil].include?(state)
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :put, response)
          when 202
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :put, response) if request_for_bindings?(uri)
            return response_hash if state == 'in progress'
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :put, response)
          when 409
            raise Errors::ServiceBrokerConflict.new(uri.to_s, :put, response)
          else
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :put, response)
          end
        end

        def parse_patch_response(code, uri, response)
          response_hash = parse_response(uri, :patch, response)
          case code
          when 200
            return response_hash
          when 422
            raise Errors::ServiceBrokerRequestRejected.new(uri.to_s, :patch, response)
          else
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :patch, response)
          end
        end

        def parse_delete_response(code, uri, response)
          response_hash = parse_response(uri, :delete, response)
          case code
          when 200
            return response_hash
          when 410
            logger.warn("Already deleted: #{uri}")
            return nil
          else
            raise Errors::ServiceBrokerBadResponse.new(uri.to_s, :delete, response)
          end
        end

        private

        def state_from_response_hash(response_hash)
          last_operation = response_hash['last_operation'] || {}
          last_operation['state']
        end

        def parse_response(uri, method, response)
          begin
            response_hash = MultiJson.load(response.body)
          rescue MultiJson::ParseError
            logger.warn("MultiJson parse error `#{response.try(:body).inspect}'")
          end

          unless response_hash.is_a?(Hash)
            raise Errors::ServiceBrokerResponseMalformed.new(uri, :method, sanitize_response(response))
          end

          response_hash
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
