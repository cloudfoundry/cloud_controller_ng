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
            return parse_catalog(method, path, response)
          when :patch
            return PatchResponse.new(@uri, response).handle(@code)
          end
        end

        def parse_catalog(method, path, response)
          pre_parse(method, path, response)

          logger ||= Steno.logger('cc.service_broker.v2.client')

          validator =
          case @code
          when 200
            JsonResponseValidator.new(logger, SuccessValidator.new)
          when 201, 202
            JsonResponseValidator.new(logger,
              FailingValidator.new(Errors::ServiceBrokerBadResponse))
          else
            FailingValidator.new(Errors::ServiceBrokerBadResponse)
          end

          _, _, _, response = validator.validate(:get, @uri, @code, response)
          MultiJson.load(response.body)
        end

        def parse_fetch_state(method, path, response)
          pre_parse(method, path, response)

          logger ||= Steno.logger('cc.service_broker.v2.client')

          validator =
          case @code
          when 200
            JsonResponseValidator.new(logger,
              StateValidator.new(['succeeded', 'failed', 'in progress'],
                SuccessValidator.new))
          when 201, 202
            JsonResponseValidator.new(logger,
              FailingValidator.new(Errors::ServiceBrokerBadResponse))
          else
            FailingValidator.new(Errors::ServiceBrokerBadResponse)
          end

          _, _, _, response = validator.validate(:get, @uri, @code, response)
          MultiJson.load(response.body)
        end

        private

        def pre_parse(method, path, response)
          @code = response.code.to_i
          @uri = uri_for(path)
          raise_for_common_errors(@code, @uri, method, response)
        end

        class SuccessValidator
          def validate(method, uri, code, response)
            [method, uri, code, response]
          end
        end

        class FailingValidator
          def initialize(error_class)
            @error_class = error_class
          end

          def validate(method, uri, code, response)
            raise @error_class.new(uri.to_s, method, response)
          end
        end

        class JsonResponseValidator
          def initialize(logger, validator)
            @logger = logger
            @validator = validator
          end

          def validate(method, uri, code, response)
            begin
              parsed_response = MultiJson.load(response.body)
            rescue MultiJson::ParseError
              @logger.warn("MultiJson parse error `#{response.try(:body).inspect}'")
            end

            unless parsed_response.is_a?(Hash)
              raise Errors::ServiceBrokerResponseMalformed.new(uri, @method, response)
            end

            @validator.validate(method, uri, code, response)
          end
        end

        class StateValidator
          def initialize(valid_states, validator)
            @valid_states = valid_states
            @validator = validator
          end

          def validate(method, uri, code, response)
            parsed_response = MultiJson.load(response.body)
            if @valid_states.include?(state_from_parsed_response(parsed_response))
              @validator.validate(method, uri, code, response)
            else
              raise Errors::ServiceBrokerResponseMalformed.new(uri.to_s, @method, response)
            end
          end

          private

          def state_from_parsed_response(parsed_response)
            parsed_response ||= {}
            last_operation = parsed_response['last_operation'] || {}
            last_operation['state']
          end
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
            unless @parsed_response.is_a?(Hash)
              raise Errors::ServiceBrokerResponseMalformed.new(@uri, method, @response)
            end
          end

          def handle_other_code(method)
            raise Errors::ServiceBrokerBadResponse.new(@uri.to_s, method, @response)
          end

          def logger
            @logger ||= Steno.logger('cc.service_broker.v2.client')
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
            when 201
              raise_if_malformed_response(:patch)
              raise Errors::ServiceBrokerBadResponse.new(@uri.to_s, :patch, @response)
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
            when 204
              {}
            when 410
              handle_410
            when 201, 202
              raise_if_malformed_response(:delete)
              raise Errors::ServiceBrokerBadResponse.new(@uri.to_s, :delete, @response)
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
            return
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
