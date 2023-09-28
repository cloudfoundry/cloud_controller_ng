module VCAP::Services
  module ServiceBrokers
    module V2
      class ResponseParser
        def initialize(url, log_errors: nil, log_validators: nil, log_response_fields: nil)
          @url = url
          @logger = Steno.logger('cc.service_broker.v2.client')
          @log_errors = log_errors || false
          @log_validators = log_validators || false
          @log_response_fields = log_response_fields || {}
        end

        def parse_provision(path, response)
          parse_unvalidated_response_with_validator(:provision, :put, path, response) do |unvalidated_response|
            validator =
              case unvalidated_response.code
              when 200, 201
                JsonSchemaValidator.new(@logger, provision_response_schema,
                                        SuccessValidator.new(state: 'succeeded'))
              when 202
                JsonSchemaValidator.new(@logger, provision_response_schema,
                                        SuccessValidator.new(state: 'in progress'))
              when 409
                FailingValidator.new(Errors::ServiceBrokerConflict)
              when 422
                FailWhenValidator.new(
                  'error',
                  {
                    'AsyncRequired' => Errors::AsyncRequired,
                    'ConcurrencyError' => Errors::ConcurrencyError,
                    'MaintenanceInfoConflict' => Errors::MaintenanceInfoConflict
                  },
                  FailingValidator.new(Errors::ServiceBrokerBadResponse)
                )
              else
                FailingValidator.new(Errors::ServiceBrokerBadResponse)
              end

            CommonErrorValidator.new(validator)
          end
        end

        def parse_bind(path, response, opts={})
          parse_unvalidated_response_with_validator(:bind, :put, path, response) do |unvalidated_response|
            validator =
              case unvalidated_response.code
              when 200, 201
                JsonObjectValidator.new(@logger,
                                        CredentialsValidator.new(
                                          SyslogDrainValidator.new(opts[:service_guid],
                                                                   RouteServiceURLValidator.new(
                                                                     VolumeMountsValidator.new(opts[:service_guid],
                                                                                               SuccessValidator.new(state: 'succeeded'))
                                                                   ))
                                        ))
              when 202
                JsonSchemaValidator.new(@logger, async_binding_response_schema, SuccessValidator.new)
              when 409
                FailingValidator.new(Errors::ServiceBrokerConflict)
              when 422
                FailWhenValidator.new('error',
                                      { 'RequiresApp' => Errors::AppRequired,
                                        'AsyncRequired' => Errors::AsyncRequired,
                                        'ConcurrencyError' => Errors::ConcurrencyError },
                                      FailingValidator.new(Errors::ServiceBrokerBadResponse))
              else
                FailingValidator.new(Errors::ServiceBrokerBadResponse)
              end

            CommonErrorValidator.new(validator)
          end
        end

        def parse_unbind(path, response)
          parse_unvalidated_response_with_validator(:unbind, :delete, path, response) do |unvalidated_response|
            validator =
              case unvalidated_response.code
              when 200
                JsonObjectValidator.new(@logger,
                                        SuccessValidator.new(state: 'succeeded'))
              when 201
                IgnoreDescriptionKeyFailingValidator.new(Errors::ServiceBrokerBadResponse)
              when 202
                JsonSchemaValidator.new(@logger, async_binding_response_schema, SuccessValidator.new)
              when 410
                @logger.warn("Already deleted: #{unvalidated_response.uri}")
                SuccessValidator.new { |_res| {} }
              when 422
                FailWhenValidator.new('error', {
                                        'AsyncRequired' => Errors::AsyncRequired,
                                        'ConcurrencyError' => Errors::ConcurrencyError
                                      }, FailingValidator.new(Errors::ServiceBrokerBadResponse))
              else
                FailingValidator.new(Errors::ServiceBrokerBadResponse)
              end

            CommonErrorValidator.new(validator)
          end
        end

        def parse_deprovision(path, response)
          parse_unvalidated_response_with_validator(:deprovision, :delete, path, response) do |unvalidated_response|
            validator =
              case unvalidated_response.code
              when 200
                JsonObjectValidator.new(@logger,
                                        SuccessValidator.new(state: 'succeeded'))
              when 201
                IgnoreDescriptionKeyFailingValidator.new(Errors::ServiceBrokerBadResponse)
              when 202
                JsonSchemaValidator.new(@logger, deprovision_response_schema,
                                        SuccessValidator.new(state: 'in progress'))
              when 410
                @logger.warn("Already deleted: #{unvalidated_response.uri}")
                SuccessValidator.new { |_res| {} }
              when 422
                FailWhenValidator.new('error', {
                                        'AsyncRequired' => Errors::AsyncRequired,
                                        'ConcurrencyError' => Errors::ConcurrencyError
                                      }, FailingValidator.new(Errors::ServiceBrokerBadResponse))
              else
                FailingValidator.new(Errors::ServiceBrokerBadResponse)
              end

            CommonErrorValidator.new(validator)
          end
        end

        def parse_catalog(path, response)
          parse_unvalidated_response_with_validator(:catalog, :get, path, response) do |unvalidated_response|
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

            CommonErrorValidator.new(validator)
          end
        end

        def parse_update(path, response)
          parse_unvalidated_response_with_validator(:update, :patch, path, response) do |unvalidated_response|
            validator =
              case unvalidated_response.code
              when 200
                JsonSchemaValidator.new(@logger, update_response_schema,
                                        SuccessValidator.new(state: 'succeeded'))
              when 201
                IgnoreDescriptionKeyFailingValidator.new(Errors::ServiceBrokerBadResponse)
              when 202
                JsonSchemaValidator.new(@logger, update_response_schema,
                                        SuccessValidator.new(state: 'in progress'))
              when 422
                FailWhenValidator.new('error', {
                                        'AsyncRequired' => Errors::AsyncRequired,
                                        'MaintenanceInfoConflict' => Errors::MaintenanceInfoConflict
                                      },
                                      FailingValidator.new(Errors::ServiceBrokerRequestRejected))
              else
                FailingValidator.new(Errors::ServiceBrokerBadResponse)
              end

            CommonErrorValidator.new(validator)
          end
        end

        def parse_fetch_state(path, response, type)
          parse_unvalidated_response_with_validator(type, :get, path, response) do |unvalidated_response|
            case unvalidated_response.code
            when 200
              JsonObjectValidator.new(
                @logger,
                StateValidator.new(
                  ['succeeded', 'failed', 'in progress'],
                  SuccessValidator.new
                )
              )
            when 201, 202
              JsonObjectValidator.new(@logger,
                                      FailingValidator.new(Errors::ServiceBrokerBadResponse))
            when 400
              BadRequestValidator.new
            when 410
              SuccessValidator.new { |_res| {} }
            else
              CommonErrorValidator.new(FailingValidator.new(Errors::ServiceBrokerBadResponse))
            end
          end
        end

        def parse_fetch_parameters(path, response, schema, type)
          parse_unvalidated_response_with_validator(type, :get, path, response) do |unvalidated_response|
            validator =
              case unvalidated_response.code
              when 200
                JsonSchemaValidator.new(@logger, schema, SuccessValidator.new)
              else
                FailingValidator.new(Errors::ServiceBrokerBadResponse)
              end

            CommonErrorValidator.new(validator)
          end
        end

        def parse_fetch_service_instance(path, response)
          parse_fetch_parameters(path, response, fetch_service_instance_response_schema, :fetch_service_instance)
        end

        def parse_fetch_service_binding(path, response)
          parse_fetch_parameters(path, response, fetch_service_binding_response_schema, :fetch_service_binding)
        end

        def parse_fetch_service_instance_last_operation(path, response)
          parse_fetch_state(path, response, :fetch_service_instance_last_operation)
        end

        def parse_fetch_service_binding_last_operation(path, response)
          parse_fetch_state(path, response, :fetch_service_binding_last_operation)
        end

        def parse_unvalidated_response_with_validator(type, method, path, response)
          log_context = { type: type, method: method, url: @url, path: path, code: response.code.to_i }
          begin
            unvalidated_response = UnvalidatedResponse.new(method, @url, path, response)
            fields = @log_response_fields[type] || []
            unvalidated_response.log_response_fields(@logger, fields, log_context) unless fields.empty?

            validator = yield unvalidated_response
            @logger.info('validators', log_context.merge({ validators: validator.stack })) if @log_validators
            validator.validate(**unvalidated_response.to_hash)
          rescue StandardError => e
            @logger.error(e.class, log_context.merge({ description: e.to_h['description'] })) if @log_errors
            raise e
          end
        end

        def async_binding_response_schema
          [:async_binding_response_schema, {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type' => 'object',
            'properties' => {
              'operation' => {
                'type' => 'string',
                'maxLength' => 10_000
              }
            }
          }]
        end

        def provision_response_schema
          [:provision_response_schema, {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type' => 'object',
            'properties' => {
              'dashboard_url' => {
                'type' => %w[string null]
              },
              'operation' => {
                'type' => 'string',
                'maxLength' => 10_000
              }
            }
          }]
        end

        def deprovision_response_schema
          [:deprovision_response_schema, {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type' => 'object',
            'properties' => {
              'operation' => {
                'type' => 'string',
                'maxLength' => 10_000
              }
            }
          }]
        end

        def update_response_schema
          [:update_response_schema, {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type' => 'object',
            'properties' => {
              'dashboard_url' => {
                'type' => %w[string null]
              },
              'operation' => {
                'type' => 'string',
                'maxLength' => 10_000
              }
            }
          }]
        end

        def fetch_service_instance_response_schema
          [:fetch_service_instance_response_schema, {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type' => 'object',
            'properties' => {
              'service_id' => {
                'type' => 'string'
              },
              'plan_id' => {
                'type' => 'string'
              },
              'dashboard_url' => {
                'type' => 'string'
              },
              'parameters' => {
                'type' => 'object'
              }
            }
          }]
        end

        def fetch_service_binding_response_schema
          [:fetch_service_binding_response_schema, {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type' => 'object',
            'properties' => {
              'parameters' => {
                'type' => 'object'
              },
              'credentials' => {
                'type' => 'object'
              },
              'syslog_drain_url' => {
                'type' => 'string'
              },
              'route_service_url' => {
                'type' => 'string'
              },
              'volume_mounts' => {
                'type' => 'array',
                'items' => {
                  'type' => 'object',
                  'required' => %w[device device_type driver mode container_dir],
                  'properties' => {
                    'device' => {
                      'type' => 'object',
                      'required' => ['volume_id'],
                      'properties' => {
                        'volume_id' => {
                          'type' => 'string'
                        },
                        'mount_config' => {
                          'type' => %w[object null]
                        }
                      }
                    },
                    'device_type' => {
                      'type' => 'string'
                    },
                    'driver' => {
                      'type' => 'string'
                    },
                    'mode' => {
                      'enum' => %w[r rw]
                    },
                    'container_dir' => {
                      'type' => 'string'
                    }
                  }
                }
              }
            }
          }]
        end

        class UnvalidatedResponse
          attr_reader :code, :uri

          def initialize(method, url, path, response)
            @method = method
            @uri = URI(url + path).to_s
            @code = response.code.to_i
            @response = response
            @parsed_response = nil
          end

          def log_response_fields(logger, fields, log_context)
            logger.info('unvalidated_response', log_context.merge({ selective_fields: select_fields(fields) }))
          end

          def to_hash
            {
              method: @method,
              uri: @uri,
              code: @code,
              response: @response,
              parsed_response: @parsed_response
            }
          end

          def select_fields(fields)
            @parsed_response ||= MultiJson.load(@response.body)
            data = {}
            fields.each do |field|
              value = @parsed_response[field]
              data[field] = value if value
            end
            data
          rescue MultiJson::ParseError
            'could not parse response'
          end
        end

        class Validator
          def initialize(validator)
            @validator = validator
          end

          def name
            self.class.name&.demodulize || 'Validator'
          end

          def info
            name
          end

          def stack
            [info] + (@validator&.stack || [])
          end
        end

        class VolumeMountsValidator < Validator
          def initialize(service_guid, validator)
            @service_guid = service_guid
            super(validator)
          end

          def info
            name + (@service_guid ? "[#{@service_guid}]" : '')
          end

          def validate(method:, uri:, code:, response:, parsed_response: nil)
            service = VCAP::CloudController::Service.first(guid: @service_guid)
            parsed_response ||= MultiJson.load(response.body)

            if !parsed_response['volume_mounts'].nil? && service.requires.exclude?('volume_mount')
              raise Errors::ServiceBrokerInvalidVolumeMounts.new(uri, method, response,
                                                                 not_required_error_description)
            end

            if !parsed_response['volume_mounts'].nil? &&
               (!parsed_response['volume_mounts'].is_a?(Array) || parsed_response['volume_mounts'].any? { |mount_info| !mount_info.is_a?(Hash) })
              raise Errors::ServiceBrokerInvalidVolumeMounts.new(uri, method, response, invalid_error_description(response.body))
            end

            unless parsed_response['volume_mounts'].nil?
              parsed_response['volume_mounts'].each do |mount_info|
                validate_mount(method, uri, response, mount_info)
              end
            end

            @validator.validate(method:, uri:, code:, response:, parsed_response:)
          end

          def validate_mount(method, uri, response, mount_info)
            %w[device_type device mode container_dir driver].each do |key|
              raise Errors::ServiceBrokerInvalidVolumeMounts.new(uri, method, response, "missing required field '#{key}'") unless mount_info.key?(key)
            end

            %w[device_type mode container_dir driver].each do |key|
              raise Errors::ServiceBrokerInvalidVolumeMounts.new(uri, method, response, "missing required field '#{key}'") unless
                mount_info[key].is_a?(String) && !mount_info[key].empty?
            end

            unless mount_info['device'].is_a?(Hash)
              raise Errors::ServiceBrokerInvalidVolumeMounts.new(uri, method, response,
                                                                 "required field 'device' must be an object but is " + mount_info['device'].class.to_s)
            end

            if mount_info['device']['volume_id'].class != String || mount_info['device']['volume_id'].empty?
              raise Errors::ServiceBrokerInvalidVolumeMounts.new(uri, method, response,
                                                                 "required field 'device.volume_id' must be a non-empty string")
            end

            return unless mount_info['device'].key?('mount_config') && !mount_info['device']['mount_config'].nil? && mount_info['device']['mount_config'].class != Hash

            raise Errors::ServiceBrokerInvalidVolumeMounts.new(uri, method, response, "field 'device.mount_config' must be an object if it is defined")
          end

          def invalid_error_description(body)
            "expected \"volume_mounts\" key to contain an array of JSON objects in body, broker returned '#{body}'"
          end

          def not_required_error_description
            'The service is attempting to supply volume mounts from your application, but is not registered as a volume mount service. ' \
              'Please contact the service provider.'
          end
        end

        class SyslogDrainValidator < Validator
          def initialize(service_guid, validator)
            @service_guid = service_guid
            super(validator)
          end

          def info
            name + (@service_guid ? "[#{@service_guid}]" : '')
          end

          def validate(method:, uri:, code:, response:, parsed_response: nil)
            service = VCAP::CloudController::Service.first(guid: @service_guid)
            parsed_response ||= MultiJson.load(response.body)
            raise Errors::ServiceBrokerInvalidSyslogDrainUrl.new(uri, method, response) if !parsed_response['syslog_drain_url'].nil? && service.requires.exclude?('syslog_drain')

            @validator.validate(method:, uri:, code:, response:, parsed_response:)
          end
        end

        class CredentialsValidator < Validator
          def validate(method:, uri:, code:, response:, parsed_response: nil)
            parsed_response ||= MultiJson.load(response.body)
            raise Errors::ServiceBrokerResponseMalformed.new(uri, @method, response, error_message) if parsed_response['credentials'] && !parsed_response['credentials'].is_a?(Hash)

            @validator.validate(method:, uri:, code:, response:, parsed_response:)
          end

          def error_message
            'expected credentials to be a valid JSON object'
          end
        end

        class RouteServiceURLValidator < Validator
          def validate(method:, uri:, code:, response:, parsed_response: nil)
            parsed_response ||= MultiJson.load(response.body)

            url = parsed_response['route_service_url']
            if url
              is_valid = true

              begin
                is_valid = valid_route_service_url?(URI.parse(url))
              rescue URI::InvalidURIError
                is_valid = false
              end

              raise Errors::ServiceBrokerBadResponse.new(uri.to_s, method, response) unless is_valid
            end

            @validator.validate(method:, uri:, code:, response:, parsed_response:)
          end

          private

          def valid_route_service_url?(parsed_url)
            parsed_url.is_a?(URI::HTTPS) && parsed_url.host && !parsed_url.host.split('.').first.empty?
          end
        end

        class FailWhenValidator < Validator
          def initialize(key, error_class_map, validator)
            @key = key
            @error_class_map = error_class_map
            super(validator)
          end

          def validate(method:, uri:, code:, response:, parsed_response: nil)
            begin
              parsed_response ||= MultiJson.load(response.body)
            rescue MultiJson::ParseError
              @validator.validate(method:, uri:, code:, response:)
              return
            end

            if @error_class_map.include?(parsed_response[@key])
              error_class = @error_class_map[parsed_response[@key].to_s]
              raise error_class.new(uri.to_s, method, response)
            else
              @validator.validate(method:, uri:, code:, response:, parsed_response:)
            end
          end
        end

        class SuccessValidator < Validator
          def initialize(state: nil, &block)
            @processor = if block_given?
                           block
                         else
                           lambda do |response, parsed_response|
                             parsed_response ||= MultiJson.load(response.body)
                             broker_response = parsed_response.dup
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
            @state = state
            super(nil)
          end

          def info
            name + (@state ? "[#{@state}]" : '')
          end

          def validate(method:, uri:, code:, response:, parsed_response: nil)
            @processor.call(response, parsed_response)
          end
        end

        class FailingValidator < Validator
          def initialize(error_class)
            @error_class = error_class
            super(nil)
          end

          def validate(method:, uri:, code:, response:, parsed_response: nil)
            raise @error_class.new(uri.to_s, method, response)
          end
        end

        class IgnoreDescriptionKeyFailingValidator < Validator
          def initialize(error_class)
            @error_class = error_class
            super(nil)
          end

          def validate(method:, uri:, code:, response:, parsed_response: nil)
            raise @error_class.new(uri.to_s, method, response, ignore_description_key: true)
          end
        end

        class JsonObjectValidator < Validator
          def initialize(logger, validator)
            @logger = logger
            super(validator)
          end

          def validate(method:, uri:, code:, response:, parsed_response: nil)
            begin
              parsed_response ||= MultiJson.load(response.body)
            rescue MultiJson::ParseError
              @logger.warn("MultiJson parse error `#{response.try(:body).inspect}'")
            end

            raise Errors::ServiceBrokerResponseMalformed.new(uri, @method, response, error_description(response)) unless parsed_response.is_a?(Hash)

            @validator.validate(method:, uri:, code:, response:, parsed_response:)
          end

          private

          def error_description(response)
            "expected valid JSON object in body, broker returned '#{response.body}'"
          end
        end

        class StateValidator < Validator
          def initialize(valid_states, validator)
            @valid_states = valid_states
            super(validator)
          end

          def info
            name + (@valid_states ? "[#{@valid_states.join(',')}]" : '')
          end

          def validate(method:, uri:, code:, response:, parsed_response: nil)
            parsed_response ||= MultiJson.load(response.body)
            state = state_from_parsed_response(parsed_response)
            raise Errors::ServiceBrokerResponseMalformed.new(uri.to_s, @method, response, error_description(state)) unless @valid_states.include?(state)

            @validator.validate(method:, uri:, code:, response:, parsed_response:)
          end

          private

          def state_from_parsed_response(parsed_response)
            (parsed_response || {})['state']
          end

          def error_description(actual)
            "expected state was 'succeeded', broker returned '#{actual}'."
          end
        end

        class CommonErrorValidator < Validator
          def validate(method:, uri:, code:, response:, parsed_response: nil)
            case code
            when 401
              raise Errors::ServiceBrokerApiAuthenticationFailed.new(uri.to_s, method, response)
            when 408
              raise Errors::ServiceBrokerApiTimeout.new(uri.to_s, method, response)
            when 409, 410, 422
              nil
            when 400..499
              raise Errors::ServiceBrokerRequestRejected.new(uri.to_s, method, response)
            when 500..599
              raise Errors::ServiceBrokerBadResponse.new(uri.to_s, method, response)
            end
            @validator.validate(method:, uri:, code:, response:, parsed_response:)
          end
        end

        class ParametersValidator < Validator
          def validate(method:, uri:, code:, response:, parsed_response: nil)
            parsed_response ||= MultiJson.load(response.body)
            parameters = parsed_response['parameters']

            if parameters && !parameters.is_a?(Hash)
              raise Errors::ServiceBrokerResponseMalformed.new(uri, method, response,
                                                               'The service broker response contained a parameters field that was not a JSON object.')
            end

            @validator.validate(method:, uri:, code:, response:, parsed_response:)
          end
        end

        class JsonSchemaValidator < Validator
          def initialize(logger, schema, validator)
            @logger = logger
            @schema_name = schema[0]
            @schema = schema[1]
            super(validator)
          end

          def info
            name + (@schema_name ? "[#{@schema_name}]" : '')
          end

          def validate(method:, uri:, code:, response:, parsed_response: nil)
            begin
              parsed_response ||= MultiJson.load(response.body)
            rescue MultiJson::ParseError
              @logger.warn("MultiJson parse error `#{response.try(:body).inspect}'")
            end

            unless parsed_response.is_a?(Hash)
              raise Errors::ServiceBrokerResponseMalformed.new(
                uri,
                method,
                response,
                "expected valid JSON object in body, broker returned '#{response.body}'"
              )
            end

            schema_validation_errors = JSON::Validator.fully_validate(@schema, response.body)

            if schema_validation_errors.any?
              err_msgs = schema_validation_errors.map { |e| remove_trailing_validation_schema_id(e) }

              raise Errors::ServiceBrokerResponseMalformed.new(uri, method, response, "\n" + err_msgs.join("\n"))
            end

            @validator.validate(method:, uri:, code:, response:, parsed_response:)
          end

          def remove_trailing_validation_schema_id(err_msg)
            err_msg.sub(/ in schema.*$/, '')
          end
        end

        class BadRequestValidator < Validator
          def initialize
            super(nil)
          end

          def validate(method:, uri:, code:, response:, parsed_response: nil)
            description = 'Bad request'
            begin
              parsed_response ||= MultiJson.load(response.body)
              description = parsed_response['description'] if parsed_response.is_a?(Hash) && parsed_response.key?('description')
            rescue MultiJson::ParseError
            end

            {
              'last_operation' => {
                'state' => 'failed',
                'description' => description
              },
              'http_status_code' => 400
            }
          end
        end
      end
    end
  end
end
