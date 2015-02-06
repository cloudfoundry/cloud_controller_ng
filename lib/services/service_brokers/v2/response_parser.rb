module VCAP::Services
  module ServiceBrokers
    module V2
      class ResponseParser
        def initialize(url)
          @url = url
        end

        def parse(method, path, response)
          pre_parse(method, path, response)

          case method
          when :put
            return PutResponse.new(@uri, response).handle(@code)
          when :delete
            return DeleteResponse.new(@uri, response).handle(@code)
          when :get
            return GetResponse.new(@uri, response).handle(@code)
          when :patch
            return PatchResponse.new(@uri, response).handle(@code)
          end
        end

        def parse_fetch_state(method, path, response)
          pre_parse(method, path, response)

          FetchStateResponse.new(@uri, response).handle(@code)
        end

        private

        def pre_parse(method, path, response)
          @code = response.code.to_i
          @uri = uri_for(path)
          raise_for_common_errors(@code, @uri, method, response)
        end

        class BaseResponse
          def initialize(uri, response)
            @uri = uri
            @response = response
          end

          def recognized_or_nil_operation_state?(state)
            ['succeeded', 'failed', 'in progress', nil].include?(@state)
          end

          def recognized_operation_state?(state)
            ['succeeded', 'failed', 'in progress'].include?(@state)
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

          def state_from_parsed_response(parsed_response)
            parsed_response ||= {}
            last_operation = parsed_response['last_operation'] || {}
            last_operation['state']
          end

          def raise_if_malformed_response(method)
            unless @parsed_response
              raise Errors::ServiceBrokerResponseMalformed.new(@uri, method, sanitize_response(@response))
            end
          end

          def handle_other_code(method)
            raise Errors::ServiceBrokerBadResponse.new(@uri.to_s, method, @response)
          end

          def sanitize_response(response)
            HttpResponse.new(
              code: response.code,
              message: response.message,
              body: "\"#{response.body}\""
            )
          end

          def logger
            @logger ||= Steno.logger('cc.service_broker.v2.client')
          end
        end

        class GetResponse < BaseResponse
          def initialize(uri, response)
            super(uri, response)
            @parsed_response = parse_response(uri, :get, response)
            @state = state_from_parsed_response(@parsed_response)
          end

          def handle(code)
            case code
            when 200
              handle_200
            when 201, 202
              raise_if_malformed_response(:get)
              raise Errors::ServiceBrokerBadResponse.new(@uri.to_s, :get, @response)
            else
              handle_other_code(:get)
            end
          end

          def handle_200
            raise_if_malformed_response(:get)
            return @parsed_response if recognized_or_nil_operation_state?(@state)
            raise Errors::ServiceBrokerResponseMalformed.new(@uri.to_s, :get, @response)
          end
        end

        class FetchStateResponse < GetResponse
          def handle_200
            parsed_response = super
            state = state_from_parsed_response(parsed_response)
            raise Errors::ServiceBrokerResponseMalformed.new(@uri, :get, sanitize_response(@response)) unless recognized_operation_state?(state)
            parsed_response
          end
        end

        class PutResponse < BaseResponse
          def initialize(uri, response)
            super(uri, response)
            @parsed_response = parse_response(@uri, :put, @response)
            if request_for_bindings?(@uri) && @parsed_response
              @parsed_response.except!('last_operation')
            end
            @state = state_from_parsed_response(@parsed_response)
          end

          def handle(code)
            handled_response =
            case code
            when 200
              handle_200
            when 201
              handle_201
            when 202
              handle_202
            when 409
              raise Errors::ServiceBrokerConflict.new(@uri.to_s, :put, @response)
            when 422
              raise Errors::AsyncRequired.new(@uri.to_s, :put, @response) if is_async_required? @parsed_response
              raise Errors::ServiceBrokerBadResponse.new(@uri.to_s, :put, @response)
            else
              handle_other_code(:put)
            end

            raise Errors::ServiceBrokerResponseMalformed.new(@uri.to_s, :put, @response) unless handled_response
            handled_response
          end

          def handle_200
            raise_if_malformed_response(:put)
            @parsed_response if recognized_or_nil_operation_state?(@state)
          end

          def handle_201
            raise_if_malformed_response(:put)
            return @parsed_response if ['succeeded', nil].include?(@state)
          end

          def handle_202
            raise_if_malformed_response(:put)
            raise Errors::ServiceBrokerBadResponse.new(@uri.to_s, :put, @response) if request_for_bindings?(@uri)
            @parsed_response if @state == 'in progress'
          end

          def request_for_bindings?(uri)
            !!%r{/v2/service_instances/[[:alnum:]-]+/service_bindings}.match(uri.to_s)
          end

          def is_async_required?(parsed_response)
            parsed_response.is_a?(Hash) && parsed_response['error'] == 'AsyncRequired'
          end
        end

        class PatchResponse < BaseResponse
          def initialize(uri, response)
            super(uri, response)
            @parsed_response = parse_response(@uri, :patch, @response)
          end

          def handle(code)
            case code
            when 200, 202
              handle_200_202
            when 422
              handle_422
            else
              raise Errors::ServiceBrokerBadResponse.new(@uri.to_s, :patch, @response)
            end
          end

          def handle_200_202
            raise_if_malformed_response(:patch)
            @parsed_response
          end

          def handle_422
            raise Errors::ServiceBrokerRequestRejected.new(@uri.to_s, :patch, @response)
          end
        end

        class DeleteResponse < BaseResponse
          def initialize(uri, response)
            super(uri, response)
            @parsed_response = parse_response(@uri, :delete, @response)
          end

          def handle(code)
            case code
            when 200
              handle_200
            when 410
              handle_410
            else
              raise Errors::ServiceBrokerBadResponse.new(@uri.to_s, :delete, @response)
            end
          end

          def handle_200
            raise_if_malformed_response(:delete)
            @parsed_response
          end

          def handle_410
            logger.warn("Already deleted: #{@uri}")
            nil
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

        def uri_for(path)
          URI(@url + path)
        end
      end
    end
  end
end
