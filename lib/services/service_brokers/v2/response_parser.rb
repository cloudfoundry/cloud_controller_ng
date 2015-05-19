module VCAP::Services
  module ServiceBrokers
    module V2
      class ResponseParser
        def initialize(url)
          @url = url
          @logger = Steno.logger('cc.service_broker.v2.client')
        end

        def parse_provision(path, response)
          unvalidated_response = UnvalidatedResponse.new(:put, @url, path, response)

          validator =
          case unvalidated_response.code
          when 200
            JsonObjectValidator.new(@logger,
                SuccessValidator.new(state: 'succeeded'))
          when 201
            JsonObjectValidator.new(@logger,
                SuccessValidator.new(state: 'succeeded'))
          when 202
            JsonObjectValidator.new(@logger,
                SuccessValidator.new(state: 'in progress'))
          when 409
            FailingValidator.new(Errors::ServiceBrokerConflict)
          when 422
            FailWhenValidator.new('error',
                                  { 'AsyncRequired' => Errors::AsyncRequired },
                                  FailingValidator.new(Errors::ServiceBrokerBadResponse))
          else
            FailingValidator.new(Errors::ServiceBrokerBadResponse)
          end

          validator = CommonErrorValidator.new(validator)
          validator.validate(unvalidated_response.to_hash)
        end

        def parse_bind(path, response, opts={})
          unvalidated_response = UnvalidatedResponse.new(:put, @url, path, response)

          validator =
            case unvalidated_response.code
            when 200, 201
              JsonObjectValidator.new(@logger,
                SyslogDrainValidator.new(opts[:service_guid],
                  SuccessValidator.new(state: 'succeeded')))
            when 202
              JsonObjectValidator.new(@logger,
                FailingValidator.new(Errors::ServiceBrokerBadResponse))
            when 409
              FailingValidator.new(Errors::ServiceBrokerConflict)
            when 422
              FailWhenValidator.new('error',
                { 'RequiresApp' => Errors::AppRequired },
                FailingValidator.new(Errors::ServiceBrokerBadResponse))
            else
              FailingValidator.new(Errors::ServiceBrokerBadResponse)
            end

          validator = CommonErrorValidator.new(validator)
          validator.validate(unvalidated_response.to_hash)
        end

        def parse_unbind(path, response)
          unvalidated_response = UnvalidatedResponse.new(:delete, @url, path, response)

          validator =
          case unvalidated_response.code
          when 200
            JsonObjectValidator.new(@logger,
                SuccessValidator.new(state: 'succeeded'))
          when 201
            IgnoreDescriptionKeyFailingValidator.new(Errors::ServiceBrokerBadResponse)
          when 202
            JsonObjectValidator.new(@logger,
              FailingValidator.new(Errors::ServiceBrokerBadResponse))
          when 204
            FailingValidator.new(Errors::ServiceBrokerBadResponse)
          when 410
            @logger.warn("Already deleted: #{unvalidated_response.uri}")
            SuccessValidator.new { |res| {} }
          else
            FailingValidator.new(Errors::ServiceBrokerBadResponse)
          end

          validator = CommonErrorValidator.new(validator)
          validator.validate(unvalidated_response.to_hash)
        end

        def parse_deprovision(path, response)
          unvalidated_response = UnvalidatedResponse.new(:delete, @url, path, response)

          validator =
            case unvalidated_response.code
            when 200
              JsonObjectValidator.new(@logger,
                SuccessValidator.new(state: 'succeeded'))
            when 201
              IgnoreDescriptionKeyFailingValidator.new(Errors::ServiceBrokerBadResponse)
            when 202
              JsonObjectValidator.new(@logger,
                SuccessValidator.new(state: 'in progress'))
            when 204
              FailingValidator.new(Errors::ServiceBrokerBadResponse)
            when 410
              @logger.warn("Already deleted: #{unvalidated_response.uri}")
              SuccessValidator.new { |res| {} }
            when 422
              FailWhenValidator.new('error', { 'AsyncRequired' => Errors::AsyncRequired },
                FailingValidator.new(Errors::ServiceBrokerBadResponse))
            else
              FailingValidator.new(Errors::ServiceBrokerBadResponse)
            end

          validator = CommonErrorValidator.new(validator)
          validator.validate(unvalidated_response.to_hash)
        end

        def parse_catalog(path, response)
          unvalidated_response = UnvalidatedResponse.new(:get, @url, path, response)

          validator =
          case unvalidated_response.code
          when 200
            JsonObjectValidator.new(@logger, SuccessValidator.new)
          when 201, 202
            JsonObjectValidator.new(@logger,
              FailingValidator.new(Errors::ServiceBrokerBadResponse))
          else
            FailingValidator.new(Errors::ServiceBrokerBadResponse)
          end

          validator = CommonErrorValidator.new(validator)
          validator.validate(unvalidated_response.to_hash)
        end

        def parse_update(path, response)
          unvalidated_response = UnvalidatedResponse.new(:patch, @url, path, response)

          validator =
          case unvalidated_response.code
          when 200
            JsonObjectValidator.new(@logger,
                SuccessValidator.new(state: 'succeeded'))
          when 201
            IgnoreDescriptionKeyFailingValidator.new(Errors::ServiceBrokerBadResponse)
          when 202
            JsonObjectValidator.new(@logger,
                SuccessValidator.new(state: 'in progress'))
          when 422
            FailWhenValidator.new('error', { 'AsyncRequired' => Errors::AsyncRequired },
              FailingValidator.new(Errors::ServiceBrokerRequestRejected))
          else
            FailingValidator.new(Errors::ServiceBrokerBadResponse)
          end

          validator = CommonErrorValidator.new(validator)
          validator.validate(unvalidated_response.to_hash)
        end

        def parse_fetch_state(path, response)
          unvalidated_response = UnvalidatedResponse.new(:get, @url, path, response)

          validator =
          case unvalidated_response.code
          when 200
            JsonObjectValidator.new(@logger,
              StateValidator.new(['succeeded', 'failed', 'in progress'],
                SuccessValidator.new))
          when 201, 202
            JsonObjectValidator.new(@logger,
              FailingValidator.new(Errors::ServiceBrokerBadResponse))
          when 410
            SuccessValidator.new { |res| {} }
          else
            FailingValidator.new(Errors::ServiceBrokerBadResponse)
          end

          validator = CommonErrorValidator.new(validator)
          validator.validate(unvalidated_response.to_hash)
        end

        class UnvalidatedResponse
          attr_reader :code, :uri

          def initialize(method, uri, path, response)
            @method = method
            @code = response.code.to_i
            @uri = URI(uri + path)
            @response = response
          end

          def body
            response.body
          end

          def to_hash
            {
              method: @method,
              uri: @uri,
              code: @code,
              response: @response,
            }
          end
        end

        class SyslogDrainValidator
          def initialize(service_guid, validator)
            @validator = validator
            @service_guid = service_guid
          end

          def validate(method:, uri:, code:, response:)
            service = VCAP::CloudController::Service.first(guid: @service_guid)
            parsed_response = MultiJson.load(response.body)
            if parsed_response.key?('syslog_drain_url') && !service.requires.include?('syslog_drain')
              raise Errors::ServiceBrokerInvalidSyslogDrainUrl.new(uri, method, response)
            end
            @validator.validate(method: method, uri: uri, code: code, response: response)
          end
        end

        class FailWhenValidator
          def initialize(key, error_class_map, validator)
            @key = key
            @error_class_map = error_class_map
            @validator = validator
          end

          def validate(method:, uri:, code:, response:)
            begin
              parsed_response = MultiJson.load(response.body)
            rescue MultiJson::ParseError
              @validator.validate(method: method, uri: uri, code: code, response: response)
              return
            end

            if @error_class_map.include?(parsed_response[@key])
              error_class = @error_class_map[parsed_response[@key].to_s]
              raise error_class.new(uri.to_s, method, response)
            else
              @validator.validate(method: method, uri: uri, code: code, response: response)
            end
          end
        end

        class SuccessValidator
          def initialize(state: nil, &block)
            if block_given?
              @processor = block
            else
              @processor = ->(response) do
                broker_response = MultiJson.load(response.body)
                state ||= broker_response.delete('state')
                return broker_response unless state

                base_body = {
                  'last_operation' => {
                    'state' => state
                  }
                }
                description = broker_response.delete('description')
                base_body['last_operation']['description'] = description if description

                broker_response.merge(base_body)
              end
            end
          end

          def validate(method:, uri:, code:, response:)
            @processor.call(response)
          end
        end

        class FailingValidator
          def initialize(error_class)
            @error_class = error_class
          end

          def validate(method:, uri:, code:, response:)
            raise @error_class.new(uri.to_s, method, response)
          end
        end

        class IgnoreDescriptionKeyFailingValidator
          def initialize(error_class)
            @error_class = error_class
          end

          def validate(method:, uri:, code:, response:)
            raise @error_class.new(uri.to_s, method, response, ignore_description_key: true)
          end
        end

        class JsonObjectValidator
          def initialize(logger, validator)
            @logger = logger
            @validator = validator
          end

          def validate(method:, uri:, code:, response:)
            begin
              parsed_response = MultiJson.load(response.body)
            rescue MultiJson::ParseError
              @logger.warn("MultiJson parse error `#{response.try(:body).inspect}'")
            end

            unless parsed_response.is_a?(Hash)
              raise Errors::ServiceBrokerResponseMalformed.new(uri, @method, response, error_description(response))
            end

            @validator.validate(method: method, uri: uri, code: code, response: response)
          end

          private

          def error_description(response)
            "expected valid JSON object in body, broker returned '#{response.body}'"
          end
        end

        class StateValidator
          def initialize(valid_states, validator)
            @valid_states = valid_states
            @validator = validator
          end

          def validate(method:, uri:, code:, response:)
            parsed_response = MultiJson.load(response.body)
            state = state_from_parsed_response(parsed_response)
            if @valid_states.include?(state)
              @validator.validate(method: method, uri: uri, code: code, response: response)
            else
              raise Errors::ServiceBrokerResponseMalformed.new(uri.to_s, @method, response, error_description(state))
            end
          end

          private

          def state_from_parsed_response(parsed_response)
            parsed_response ||= {}
            parsed_response['state']
          end

          def error_description(actual)
            "expected state was 'succeeded', broker returned '#{actual}'."
          end
        end

        class CommonErrorValidator
          def initialize(validator)
            @validator = validator
          end

          def validate(method:, uri:, code:, response:)
            case code
            when 401
              raise Errors::ServiceBrokerApiAuthenticationFailed.new(uri.to_s, method, response)
            when 408
              raise Errors::ServiceBrokerApiTimeout.new(uri.to_s, method, response)
            when 409, 410, 422
            when 400..499
              raise Errors::ServiceBrokerRequestRejected.new(uri.to_s, method, response)
            when 500..599
              raise Errors::ServiceBrokerBadResponse.new(uri.to_s, method, response)
            end
            @validator.validate(method: method, uri: uri, code: code, response: response)
          end
        end
      end
    end
  end
end
