require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      RSpec.describe 'ResponseParser' do
        describe 'UnvalidatedResponse' do
          let(:fake_response) { VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: 200, body: {}) }

          it 'should raise an error if the uri is invalid' do
            expect { ResponseParser::UnvalidatedResponse.new(:get, 'http://examp', 'bad path', fake_response) }.to raise_error(URI::InvalidURIError)
          end
        end

        class InnerValidator
          def validate(_broker_response)
            raise NotImpementedError.new('implement this in the spec')
          end
        end

        describe 'JsonSchemaValidator' do
          let(:json_validator) { ResponseParser::JsonSchemaValidator.new(logger, schema, inner_validator) }
          let(:logger) { instance_double(Steno::Logger, warn: nil) }
          let(:schema) {
            {
              '$schema' => 'http://json-schema.org/draft-04/schema#',
              'type' => 'object',
              'properties' => {},
            }
          }
          let(:inner_validator) { instance_double(InnerValidator) }
          let(:broker_response) {
            ResponseParser::UnvalidatedResponse.new('GET', 'https://example.com', '/path',
                                                    HttpResponse.new(
                                                      code: '200',
                                                      body: broker_response_body,
            ))
          }

          before do
            allow(Steno).to receive(:logger).and_return(logger)
            allow(inner_validator).to receive(:validate).and_return('inner-validator-result')
          end

          context 'when the broker response body is valid' do
            let(:broker_response_body) { '{}' }
            it 'does not raise' do
              expect { json_validator.validate(broker_response.to_hash) }.not_to raise_error
            end

            it 'returns the inner validator result' do
              expect(json_validator.validate(broker_response.to_hash)).to eql('inner-validator-result')
            end

            it 'calls the inner validator with the same parameters it was passed' do
              json_validator.validate(broker_response.to_hash)
              expect(inner_validator).to have_received(:validate).with(broker_response.to_hash)
            end
          end

          context 'when the broker response is not a top-level JSON object' do
            ['invalid', '[]', '"not-top-level-object"'].each do |body|
              context "and the response body is #{body}" do
                let(:broker_response_body) { body }
                it 'raises' do
                  expect { json_validator.validate(broker_response.to_hash) }.to raise_error(Errors::ServiceBrokerResponseMalformed) do |e|
                    expect(e.to_h['description']).to eq(
                      "The service broker returned an invalid response: expected valid JSON object in body, broker returned '#{body}'")
                    expect(e.response_code).to eq(502)
                    expect(e.to_h['http']['method']).to eq('GET')
                    expect(e.to_h['http']['status']).to eq(200)
                  end
                end
              end
            end

            context 'and the response body is not able to be parsed' do
              let(:broker_response_body) { 'invalid' }
              it 'logs the error' do
                begin
                  json_validator.validate(broker_response.to_hash)
                rescue
                  # this is tested above
                end

                expect(logger).to have_received(:warn).with "MultiJson parse error `\"invalid\"'"
              end
            end
          end

          context 'when the schema has required properties' do
            let(:schema) {
              {
                'id' => 'some-id',
                '$schema' => 'http://json-schema.org/draft-04/schema#',
                'type' => 'object',
                'required' => ['prop1', 'prop2'],
                'properties' => {
                  'prop1' => {
                    'type' => 'boolean',
                  },
                  'prop2' => {
                    'type' => 'string',
                  }
                }
              }
            }

            context 'and there is a single validation failure' do
              let(:broker_response_body) {
                {
                  prop1: true
                }.to_json
              }

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { json_validator.validate(broker_response.to_hash) }.to raise_error(Errors::ServiceBrokerResponseMalformed) do |e|
                  description_lines = e.to_h['description'].split("\n")
                  expect(description_lines[0]).to eq('The service broker returned an invalid response: ')
                  expect(description_lines.drop(1)).to contain_exactly("The property '#/' did not contain a required property of 'prop2'")
                  expect(e.response_code).to eq(502)
                  expect(e.to_h['http']['method']).to eq('GET')
                  expect(e.to_h['http']['status']).to eq(200)
                end
              end
            end

            context 'and there are multiple validation failures' do
              let(:broker_response_body) {
                {
                }.to_json
              }

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { json_validator.validate(broker_response.to_hash) }.to raise_error(Errors::ServiceBrokerResponseMalformed) do |e|
                  description_lines = e.to_h['description'].split("\n")
                  expect(description_lines[0]).to eq('The service broker returned an invalid response: ')
                  expect(description_lines.drop(1)).to contain_exactly(
                    "The property '#/' did not contain a required property of 'prop2'",
                    "The property '#/' did not contain a required property of 'prop1'")
                  expect(e.response_code).to eq(502)
                  expect(e.to_h['http']['method']).to eq('GET')
                  expect(e.to_h['http']['status']).to eq(200)
                end
              end
            end
          end
        end

        def get_method_and_path(operation)
          case operation
          when :provision
            method = :parse_provision
            path = '/v2/service_instances/GUID'
          when :deprovision
            method = :parse_deprovision
            path = '/v2/service_instances/GUID'
          when :update
            method = :parse_update
            path = '/v2/service_instances/GUID'
          when :bind
            method = :parse_bind
            path = '/v2/service_instances/GUID/service_bindings/BINDING_GUID'
          when :unbind
            method = :parse_unbind
            path = '/v2/service_instances/GUID/service_bindings/BINDING_GUID'
          when :fetch_state
            method = :parse_fetch_state
            path = '/v2/service_instances/GUID'
          when :fetch_catalog
            method = :parse_catalog
            path = '/v2/catalog'
          when :fetch_service_binding
            method = :parse_fetch_binding_parameters
            path = '/v2/service_instances/GUID/service_bindings/BINDING_GUID'
          when :fetch_service_instance
            method = :parse_fetch_instance_parameters
            path = '/v2/service_instances/GUID'
          when :fetch_service_binding_last_operation
            method = :parse_fetch_service_binding_last_operation
            path = '/v2/service_instances/GUID/service_bindings/BINDING_GUID/last_operation'

          end

          [method, path]
        end

        def self.test_common_error_cases(operation)
          test_case(operation, 302, broker_partial_json,   error: Errors::ServiceBrokerBadResponse)
          test_case(operation, 302, broker_malformed_json, error: Errors::ServiceBrokerBadResponse)
          test_case(operation, 302, broker_empty_json,     error: Errors::ServiceBrokerBadResponse)
          test_case(operation, 401, broker_partial_json,   error: Errors::ServiceBrokerApiAuthenticationFailed)
          test_case(operation, 401, broker_malformed_json, error: Errors::ServiceBrokerApiAuthenticationFailed)
          test_case(operation, 401, broker_empty_json,     error: Errors::ServiceBrokerApiAuthenticationFailed)
          test_case(operation, 404, broker_partial_json,   error: Errors::ServiceBrokerRequestRejected)
          test_case(operation, 404, broker_malformed_json, error: Errors::ServiceBrokerRequestRejected)
          test_case(operation, 404, broker_empty_json,     error: Errors::ServiceBrokerRequestRejected)
          test_case(operation, 500, broker_partial_json,   error: Errors::ServiceBrokerBadResponse)
          test_case(operation, 500, broker_malformed_json, error: Errors::ServiceBrokerBadResponse)
          test_case(operation, 500, broker_empty_json,     error: Errors::ServiceBrokerBadResponse)
        end

        def self.test_pass_through(operation, status, with_body={}, expected_state:)
          response_body = with_additional_field
          response_body.merge!(with_body)

          # We expect to pass thru all params except 'state', which gets placed in the last_operation section
          expected_client_result = client_result_with_state(expected_state).merge(response_body.except('state'))
          test_case(operation, status, response_body.to_json, result: expected_client_result)
        end

        def self.test_case(operation, code, body, opts={})
          expect_warning = !!opts[:expect_warning]
          description = opts[:description]
          result = opts[:result]
          error = opts[:error]
          service_passthrough = opts[:service]

          context "making a #{operation} request that returns code #{code} and body #{body}" do
            let!(:syslog_service) { VCAP::CloudController::Service.make(:v2, requires: ['syslog_drain']) }
            let!(:non_syslog_non_volume_mounts_service) { VCAP::CloudController::Service.make(:v2, requires: []) }
            let!(:volume_mounts_service) { VCAP::CloudController::Service.make(:v2, requires: ['volume_mount']) }
            let(:response_parser) { ResponseParser.new('service-broker.com') }
            let(:fake_response) { instance_double(VCAP::Services::ServiceBrokers::V2::HttpResponse) }
            let(:body) { body }
            let(:logger) { instance_double(Steno::Logger, warn: nil) }
            let(:call_method) do
              ->(response_parser, method_name, path, fake_response, service_param) do
                if service_param
                  service = case service_param
                            when :syslog
                              syslog_service
                            when :volume_mount
                              volume_mounts_service
                            else
                              non_syslog_non_volume_mounts_service
                            end

                  response_parser.send(method_name, path, fake_response, service_guid: service.guid)
                else
                  response_parser.send(method_name, path, fake_response)
                end
              end
            end

            before do
              @method, @path = get_method_and_path(operation)
              allow(fake_response).to receive(:code).and_return(code)
              allow(fake_response).to receive(:body).and_return(body)
              allow(fake_response).to receive(:message).and_return('message')
              allow(Steno).to receive(:logger).and_return(logger)
            end

            if error
              it "raises a #{error} error" do
                expect { call_method.call(response_parser, @method, @path, fake_response, service_passthrough) }.to raise_error(error) do |e|
                  expect(e.to_h['description']).to eq(description) if description
                end
                expect(logger).to have_received(:warn) if expect_warning
              end
            else
              it 'returns the parsed response' do
                expect(call_method.call(response_parser, @method, @path, fake_response, service_passthrough)).to eq(result)
              end
            end
          end
        end

        def self.instance_uri
          'service-broker.com/v2/service_instances/GUID'
        end

        def self.binding_uri
          'service-broker.com/v2/service_instances/GUID/service_bindings/BINDING_GUID'
        end

        def self.binding_last_operation_uri
          'service-broker.com/v2/service_instances/GUID/service_bindings/BINDING_GUID/last_operation'
        end

        def self.broker_partial_json
          '""'
        end

        def self.broker_malformed_json
          'shenanigans'
        end

        def self.broker_empty_json
          '{}'
        end

        def self.broker_error_json(description: nil)
          response = {
            'error' => 'BadRequest',
          }

          response['description'] = description unless description.nil?

          response.to_json
        end

        def self.broker_non_empty_json
          {
            'last_operation' => {
              'state' => 'foobar',
              'random' => 'pants'
            }
          }.to_json
        end

        def self.broker_body_with_state(state)
          {
            'state' => state,
          }
        end

        def self.with_dashboard_url
          {
            'dashboard_url' => 'url.com/foo'
          }
        end

        def self.with_null_dashboard_url
          {
            'dashboard_url' => nil
          }
        end

        def self.with_invalid_dashboard_url
          {
            'dashboard_url' =>  {
              'foo' => 'bar'
            }
          }
        end

        def self.with_valid_route_service_url
          {
            'route_service_url' => 'https://route-service.cf-apps.io'
          }
        end

        def self.with_http_route_service_url
          {
            'route_service_url' => 'http://route-service.cf-apps.io'
          }
        end

        def self.with_invalid_route_service_url_with_space
          {
              'route_service_url' => 'http:/route-service.cf apps.io'
          }
        end

        def self.with_invalid_route_service_url_with_no_host
          {
            'route_service_url' => 'https://.com'
          }
        end

        def self.with_credentials
          {
            'credentials' => {
              'user' => 'user',
              'password' => 'password'
            }
          }
        end

        def self.with_syslog_drain_url
          {
            'syslog_drain_url' => 'syslog.com/drain'
          }
        end

        def self.with_nil_syslog_drain_url
          {
            'syslog_drain_url' => nil
          }
        end

        def self.with_additional_field
          {
            'foo' => 'bar'
          }
        end

        def self.with_operation
          {
            'operation' => 'g' * 10_000
          }
        end

        def self.with_long_operation
          {
            'operation' => 'g' * 10_001
          }
        end

        def self.with_non_string_operation
          {
            'operation' => { 'excellent' => 'adventure' }
          }
        end

        def self.valid_catalog
          {
            'services' => [
              {
                'id' => '12345',
                'name' => 'valid service name',
                'description' => 'valid service description',
                'plans' => [
                  {
                    'id' => 'valid plan guid',
                    'name' => 'valid plan name',
                    'description' => 'plan description'
                  }
                ]
              }
            ]
          }
        end

        def self.client_result_with_state(state, description: nil, status_code: nil)
          response_body = {
            'last_operation' => {
              'state' => state,
            }
          }

          response_body['last_operation']['description'] = description if description
          response_body['http_status_code'] = status_code if status_code
          response_body
        end

        def self.response_not_understood(expected_state, actual_state, uri)
          actual_state = actual_state ? "'#{actual_state}'" : 'null'
          'The service broker returned an invalid response: ' \
          "expected state was '#{expected_state}', broker returned #{actual_state}."
        end

        def self.invalid_json_error(body, uri)
          'The service broker returned an invalid response: ' \
          "expected valid JSON object in body, broker returned '#{body}'"
        end

        def self.broker_returned_an_error(status, body, uri)
          'The service broker returned an invalid response. ' \
          "Status Code: #{status} message, Body: #{body}"
        end

        def self.invalid_volume_mounts_error(body, uri)
          'The service broker returned an invalid response: ' \
          "expected \"volume_mounts\" key to contain an array of JSON objects in body, broker returned '#{body}'"
        end

        def self.invalid_volume_mounts_missing_field_error(field, uri)
          'The service broker returned an invalid response: ' \
          "missing required field '#{field}'"
        end

        def self.invalid_volume_mounts_missing_volume_id_error(uri)
          'The service broker returned an invalid response: ' \
          "required field 'device.volume_id' must be a non-empty string"
        end

        def self.invalid_volume_mounts_bad_mount_config_error(uri)
          'The service broker returned an invalid response: ' \
          "field 'device.mount_config' must be an object if it is defined"
        end

        def self.invalid_volume_mounts_device_type_error(uri)
          'The service broker returned an invalid response: ' \
          "required field 'device' must be an object but is String"
        end

        def self.volume_mounts_not_required_error(uri)
          'The service broker returned an invalid response: ' \
          'The service is attempting to supply volume mounts from your application, but is not registered as a volume mount service. ' \
          'Please contact the service provider.'
        end

        def self.malformed_response_error(uri, message)
          "The service broker returned an invalid response: #{message}"
        end

        def self.broker_bad_response_error(uri, message)
          "The service broker returned an invalid response. #{message}"
        end

        def self.broker_timeout_error(uri)
          'The request to the service broker timed out'
        end

        def self.with_valid_volume_mounts
          {
            'volume_mounts' => [{ 'device_type' => 'none', 'device' => { 'volume_id' => 'foo' }, 'mode' => 'r', 'container_dir' => 'none', 'driver' => 'none' }]
          }
        end

        def self.with_valid_volume_mounts_nil_mount_config
          {
            'volume_mounts' => [{
                'device_type' => 'none',
                'device' => { 'volume_id' => 'foo', 'mount_config' => nil },
                'mode' => 'r',
                'container_dir' => 'none',
                'driver' => 'none'
              }]
          }
        end

        def self.with_invalid_volume_mounts
          {
            'volume_mounts' => {}
          }
        end

        def self.with_invalid_volume_mounts_device_type
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'device' => 'foo', 'mode' => 'r', 'container_dir' => 'none', 'driver' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_nil_driver
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'mode' => 'r', 'container_dir' => 'none', 'driver' => nil, 'device' => { 'volume_id' => 'foo' } }
            ]
          }
        end

        def self.with_invalid_volume_mounts_empty_driver
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'mode' => 'r', 'container_dir' => 'none', 'driver' => '', 'device' => { 'volume_id' => 'foo' } }
            ]
          }
        end

        def self.with_invalid_volume_mounts_no_device
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'mode' => 'r', 'container_dir' => 'none', 'driver' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_no_device_type
          {
            'volume_mounts' => [
              { 'device' => { 'volume_id' => 'foo' }, 'mode' => 'r', 'container_dir' => 'none', 'driver' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_bad_device_type
          {
            'volume_mounts' => [
              { 'device_type' => 5, 'device' => { 'volume_id' => 'foo' }, 'mode' => 'r', 'container_dir' => 'none', 'driver' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_no_mode
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'device' => { 'volume_id' => 'foo' }, 'container_dir' => 'none', 'driver' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_bad_mode_type
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'device' => { 'volume_id' => 'foo' }, 'mode' => 3, 'container_dir' => 'none', 'driver' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_bad_mode_value
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'device' => { 'volume_id' => 'foo' }, 'mode' => 'read', 'container_dir' => 'none', 'driver' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_no_container_dir
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'device' => { 'volume_id' => 'foo' }, 'mode' => 'r', 'driver' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_bad_container_dir
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'device' => { 'volume_id' => 'foo' }, 'mode' => 'r', 'container_dir' => false, 'driver' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_no_driver
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'device' => { 'volume_id' => 'foo' }, 'mode' => 'r', 'container_dir' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_no_volume_id
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'device' => {}, 'mode' => 'r', 'container_dir' => 'none', 'driver' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_bad_volume_id
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'device' => { 'volume_id' => 4 }, 'mode' => 'r', 'container_dir' => 'none', 'driver' => 'none' }
            ]
          }
        end

        def self.with_invalid_volume_mounts_bad_mount_config
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'device' => { 'volume_id' => 'foo', 'mount_config' => 'foo' }, 'mode' => 'r', 'container_dir' => 'none', 'driver' => 'none' }
            ]
          }
        end

        def self.without_volume_mounts
          {
          }
        end

        # rubocop:disable Layout/LineLength
        test_case(:provision, 200, broker_partial_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:provision, 200, broker_malformed_json,                                       error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:provision, 200, broker_empty_json,                                           result: client_result_with_state('succeeded'))
        test_case(:provision, 200, with_dashboard_url.to_json,                                  result: client_result_with_state('succeeded').merge(with_dashboard_url))
        test_pass_through(:provision, 200, with_dashboard_url,                                  expected_state: 'succeeded')
        test_case(:provision, 200, with_invalid_dashboard_url.to_json,                          error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/dashboard_url' of type object did not match one or more of the following types: string, null"))
        test_case(:provision, 201, broker_partial_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:provision, 201, broker_malformed_json,                                       error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:provision, 201, broker_empty_json,                                           result: client_result_with_state('succeeded'))
        test_case(:provision, 201, with_dashboard_url.to_json,                                  result: client_result_with_state('succeeded').merge(with_dashboard_url))
        test_pass_through(:provision, 201, with_dashboard_url,                                  expected_state: 'succeeded')
        test_pass_through(:provision, 201, with_null_dashboard_url,                             expected_state: 'succeeded')
        test_case(:provision, 201, with_invalid_dashboard_url.to_json,                          error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/dashboard_url' of type object did not match one or more of the following types: string, null"))
        test_case(:provision, 202, broker_partial_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:provision, 202, broker_malformed_json,                                       error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:provision, 202, broker_empty_json,                                           result: client_result_with_state('in progress'))
        test_case(:provision, 202, broker_non_empty_json,                                       result: client_result_with_state('in progress'))
        test_case(:provision, 202, with_dashboard_url.to_json,                                  result: client_result_with_state('in progress').merge(with_dashboard_url))
        test_case(:provision, 202, with_operation.to_json,                                      result: client_result_with_state('in progress').merge(with_operation))
        test_case(:provision, 202, with_non_string_operation.to_json,                           error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/operation' of type object did not match the following type: string"))
        test_case(:provision, 202, with_long_operation.to_json,                                 error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/operation' was not of a maximum string length of 10000"))
        test_pass_through(:provision, 202, with_dashboard_url,                                  expected_state: 'in progress')
        test_pass_through(:provision, 202, with_null_dashboard_url,                             expected_state: 'in progress')
        test_case(:provision, 202, with_invalid_dashboard_url.to_json,                          error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/dashboard_url' of type object did not match one or more of the following types: string, null"))
        test_case(:provision, 204, broker_partial_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 204, broker_malformed_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 204, broker_empty_json,                                           error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 409, broker_partial_json,                                         error: Errors::ServiceBrokerConflict)
        test_case(:provision, 409, broker_malformed_json,                                       error: Errors::ServiceBrokerConflict)
        test_case(:provision, 409, broker_empty_json,                                           error: Errors::ServiceBrokerConflict)
        test_case(:provision, 410, broker_partial_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 410, broker_malformed_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 410, broker_empty_json,                                           error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 422, broker_partial_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 422, broker_malformed_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 422, broker_empty_json,                                           error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 422, { error: 'AsyncRequired' }.to_json,                          error: Errors::AsyncRequired)
        test_case(:provision, 422, { error: 'RequiresApp' }.to_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 422, { error: 'ConcurrencyError' }.to_json,                       error: Errors::ConcurrencyError)
        test_case(:provision, 422, { error: 'MaintenanceInfoConflict' }.to_json,                error: Errors::MaintenanceInfoConflict)
        test_common_error_cases(:provision)

        test_case(:bind,      200, broker_partial_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, binding_uri))
        test_case(:bind,      200, broker_malformed_json,                                       error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, binding_uri))
        test_case(:bind,      200, broker_empty_json,                                           result: client_result_with_state('succeeded'))
        test_case(:bind,      200, with_credentials.to_json,                                    result: client_result_with_state('succeeded').merge(with_credentials))
        test_case(:bind,      200, { 'credentials' => 'invalid' }.to_json,                      error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, 'expected credentials to be a valid JSON object'))
        test_case(:bind,      200, with_syslog_drain_url.to_json, service: :syslog,             result: client_result_with_state('succeeded').merge('syslog_drain_url' => 'syslog.com/drain'))
        test_case(:bind,      200, with_nil_syslog_drain_url.to_json, service: :no_syslog,      result: client_result_with_state('succeeded').merge('syslog_drain_url' => nil))
        test_case(:bind,      200, with_syslog_drain_url.to_json, service: :no_syslog,          error: Errors::ServiceBrokerInvalidSyslogDrainUrl)
        test_case(:bind,      200, with_valid_route_service_url.to_json,                        result: client_result_with_state('succeeded').merge(with_valid_route_service_url))
        test_case(:bind,      200, with_invalid_route_service_url_with_space.to_json,           error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      200, with_invalid_route_service_url_with_no_host.to_json,         error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      200, with_http_route_service_url.to_json,                         error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      200, with_invalid_volume_mounts.to_json, service: :volume_mount,  error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_error(with_invalid_volume_mounts.to_json, binding_uri))
        test_case(:bind,      200, with_valid_volume_mounts.to_json, service: :volume_mount,    result: client_result_with_state('succeeded').merge(with_valid_volume_mounts))
        test_case(:bind,      200, without_volume_mounts.to_json, service: :no_volume_mount,    result: client_result_with_state('succeeded'))
        test_case(:bind,      200, with_valid_volume_mounts.to_json, service: :no_volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: volume_mounts_not_required_error(binding_uri))
        test_case(:bind,      200, with_invalid_volume_mounts_device_type.to_json, service: :volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_device_type_error(binding_uri))
        test_case(:bind,      200, with_invalid_volume_mounts_nil_driver.to_json, service: :volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_missing_field_error('driver', binding_uri))
        test_case(:bind,      200, with_invalid_volume_mounts_empty_driver.to_json, service: :volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_missing_field_error('driver', binding_uri))
        test_case(:bind,      200, with_invalid_volume_mounts_no_device.to_json, service: :volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_missing_field_error('device', binding_uri))
        test_case(:bind,      200, with_invalid_volume_mounts_no_device_type.to_json, service: :volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_missing_field_error('device_type', binding_uri))
        test_case(:bind,      200, with_invalid_volume_mounts_no_mode.to_json, service: :volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_missing_field_error('mode', binding_uri))
        test_case(:bind,      200, with_invalid_volume_mounts_no_container_dir.to_json, service: :volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_missing_field_error('container_dir', binding_uri))
        test_case(:bind,      200, with_invalid_volume_mounts_no_driver.to_json, service: :volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_missing_field_error('driver', binding_uri))
        test_case(:bind,      200, with_invalid_volume_mounts_no_volume_id.to_json, service: :volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_missing_volume_id_error(binding_uri))
        test_case(:bind,      200, with_invalid_volume_mounts_bad_volume_id.to_json, service: :volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_missing_volume_id_error(binding_uri))
        test_case(:bind,      200, with_invalid_volume_mounts_bad_mount_config.to_json, service: :volume_mount,  error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_bad_mount_config_error(binding_uri))
        test_case(:bind,      200, with_valid_volume_mounts_nil_mount_config.to_json, service: :volume_mount,    result: client_result_with_state('succeeded').merge(with_valid_volume_mounts_nil_mount_config))
        test_pass_through(:bind, 200, with_credentials,                                         expected_state: 'succeeded')

        test_case(:bind,      201, broker_partial_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, binding_uri))
        test_case(:bind,      201, broker_malformed_json,                                       error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, binding_uri))
        test_case(:bind,      201, broker_empty_json,                                           result: client_result_with_state('succeeded'))
        test_case(:bind,      201, with_credentials.to_json,                                    result: client_result_with_state('succeeded').merge(with_credentials))
        test_case(:bind,      201, { 'credentials' => 'invalid' }.to_json,                      error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, 'expected credentials to be a valid JSON object'))
        test_case(:bind,      201, with_syslog_drain_url.to_json, service: :syslog,             result: client_result_with_state('succeeded').merge('syslog_drain_url' => 'syslog.com/drain'))
        test_case(:bind,      201, with_syslog_drain_url.to_json, service: :no_syslog,          error: Errors::ServiceBrokerInvalidSyslogDrainUrl)
        test_case(:bind,      201, with_nil_syslog_drain_url.to_json, service: :no_syslog,      result: client_result_with_state('succeeded').merge('syslog_drain_url' => nil))
        test_case(:bind,      201, with_valid_route_service_url.to_json,                        result: client_result_with_state('succeeded').merge(with_valid_route_service_url))
        test_case(:bind,      201, with_invalid_route_service_url_with_space.to_json,           error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      201, with_invalid_route_service_url_with_no_host.to_json,         error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      201, with_http_route_service_url.to_json,                         error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      201, with_invalid_volume_mounts.to_json, service: :volume_mount,  error: Errors::ServiceBrokerInvalidVolumeMounts, description: invalid_volume_mounts_error(with_invalid_volume_mounts.to_json, binding_uri))
        test_case(:bind,      201, with_valid_volume_mounts.to_json, service: :volume_mount,    result: client_result_with_state('succeeded').merge(with_valid_volume_mounts))
        test_case(:bind,      201, without_volume_mounts.to_json, service: :no_volume_mount,    result: client_result_with_state('succeeded'))
        test_case(:bind,      201, with_valid_volume_mounts.to_json, service: :no_volume_mount, error: Errors::ServiceBrokerInvalidVolumeMounts, description: volume_mounts_not_required_error(binding_uri))
        test_pass_through(:bind, 201, with_credentials,                                         expected_state: 'succeeded')

        test_case(:bind,      202, broker_empty_json,                                             result: {})
        test_case(:bind,      202, with_operation.to_json,                                        result: with_operation)
        test_case(:bind,      202, broker_malformed_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_malformed_json, binding_uri))
        test_case(:bind,      202, broker_partial_json,                                           error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, binding_uri))
        test_case(:bind,      202, with_non_string_operation.to_json,                             error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/operation' of type object did not match the following type: string"))
        test_case(:bind,      202, with_long_operation.to_json,                                   error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/operation' was not of a maximum string length of 10000"))
        test_case(:bind,      204, broker_partial_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      204, broker_malformed_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      204, broker_empty_json,                                           error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      409, broker_partial_json,                                         error: Errors::ServiceBrokerConflict)
        test_case(:bind,      409, broker_malformed_json,                                       error: Errors::ServiceBrokerConflict)
        test_case(:bind,      409, broker_empty_json,                                           error: Errors::ServiceBrokerConflict)
        test_case(:bind,      410, broker_partial_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      410, broker_malformed_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      410, broker_empty_json,                                           error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      422, broker_partial_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      422, broker_malformed_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      422, broker_empty_json,                                           error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      422, { error: 'AsyncRequired' }.to_json,                          error: Errors::AsyncRequired)
        test_case(:bind,      422, { error: 'RequiresApp' }.to_json,                            error: Errors::AppRequired)
        test_case(:bind,      422, { error: 'ConcurrencyError' }.to_json,                       error: Errors::ConcurrencyError)
        test_common_error_cases(:bind)

        test_case(:fetch_state, 200, broker_partial_json,                                       error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:fetch_state, 200, broker_malformed_json,                                     error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_malformed_json, instance_uri), expect_warning: true)
        test_case(:fetch_state, 200, broker_empty_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: response_not_understood('succeeded', '', instance_uri))
        test_case(:fetch_state, 200, broker_body_with_state('unrecognized').to_json,            error: Errors::ServiceBrokerResponseMalformed, description: response_not_understood('succeeded', 'unrecognized', instance_uri))
        test_case(:fetch_state, 200, broker_body_with_state('succeeded').to_json,               result: client_result_with_state('succeeded'))
        test_case(:fetch_state, 200, broker_body_with_state('succeeded').merge('description' => 'a description').to_json, result: client_result_with_state('succeeded', description: 'a description'))
        test_pass_through(:fetch_state, 200, broker_body_with_state('succeeded'),               expected_state: 'succeeded')
        test_case(:fetch_state, 201, broker_partial_json,                                       error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_state, 201, broker_malformed_json,                                     error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_state, 201, broker_body_with_state('succeeded').to_json,               error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 202, broker_partial_json,                                       error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_state, 202, broker_malformed_json,                                     error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_state, 202, broker_body_with_state('succeeded').to_json,               error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 204, broker_partial_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 204, broker_malformed_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 204, broker_empty_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 409, broker_partial_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 409, broker_malformed_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 409, broker_empty_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 400, broker_empty_json,                                         result: client_result_with_state('failed', description: 'Bad request', status_code: 400))
        test_case(:fetch_state, 400, broker_partial_json,                                       result: client_result_with_state('failed', description: 'Bad request', status_code: 400))
        test_case(:fetch_state, 400, broker_malformed_json,                                     result: client_result_with_state('failed', description: 'Bad request', status_code: 400))
        test_case(:fetch_state, 400, broker_error_json,                                         result: client_result_with_state('failed', description: 'Bad request', status_code: 400))
        test_case(:fetch_state, 400, broker_error_json(description: 'Some description'),        result: client_result_with_state('failed', description: 'Some description', status_code: 400))
        test_case(:fetch_state, 410, broker_empty_json,                                         result: {})
        test_case(:fetch_state, 410, broker_partial_json,                                       result: {})
        test_case(:fetch_state, 410, broker_malformed_json,                                     result: {})
        test_case(:fetch_state, 422, broker_partial_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 422, broker_malformed_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 422, broker_empty_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_common_error_cases(:fetch_state)

        test_case(:fetch_catalog, 200, broker_partial_json,                                     error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_catalog, 200, broker_malformed_json,                                   error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_catalog, 200, broker_empty_json,                                       result: {})
        test_case(:fetch_catalog, 200, valid_catalog.to_json,                                   result: valid_catalog)
        test_case(:fetch_catalog, 201, broker_partial_json,                                     error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_catalog, 201, broker_malformed_json,                                   error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_catalog, 201, broker_empty_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 201, valid_catalog.to_json,                                   error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 204, broker_partial_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 204, broker_malformed_json,                                   error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 204, broker_empty_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 204, valid_catalog.to_json,                                   error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 409, broker_partial_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 409, broker_malformed_json,                                   error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 409, broker_empty_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 410, broker_partial_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 410, broker_malformed_json,                                   error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 410, broker_empty_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 422, broker_partial_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 422, broker_malformed_json,                                   error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 422, broker_empty_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_common_error_cases(:fetch_catalog)

        test_case(:deprovision, 200, broker_partial_json,                                       error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:deprovision, 200, broker_malformed_json,                                     error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:deprovision, 200, broker_empty_json,                                         result: client_result_with_state('succeeded'))
        test_pass_through(:deprovision, 200,                                                    expected_state: 'succeeded')
        test_case(:deprovision, 201, broker_partial_json,                                       error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_partial_json, instance_uri))
        test_case(:deprovision, 201, broker_malformed_json,                                     error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_malformed_json, instance_uri))
        test_case(:deprovision, 201, broker_empty_json,                                         error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_empty_json, instance_uri))
        test_case(:deprovision, 201, { description: 'error' }.to_json,                          error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, { description: 'error' }.to_json, instance_uri))
        test_case(:deprovision, 202, broker_partial_json,                                       error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:deprovision, 202, broker_malformed_json,                                     error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:deprovision, 202, broker_empty_json,                                         result: client_result_with_state('in progress'))
        test_case(:deprovision, 202, broker_non_empty_json,                                     result: client_result_with_state('in progress'))
        test_case(:deprovision, 202, with_operation.to_json,                                    result: client_result_with_state('in progress').merge(with_operation))
        test_case(:deprovision, 202, with_non_string_operation.to_json,                         error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/operation' of type object did not match the following type: string"))
        test_case(:deprovision, 202, with_long_operation.to_json,                               error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/operation' was not of a maximum string length of 10000"))
        test_pass_through(:deprovision, 202,                                                    expected_state: 'in progress')
        test_case(:deprovision, 204, broker_partial_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 204, broker_malformed_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 204, broker_empty_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 409, broker_partial_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 409, broker_malformed_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 410, broker_empty_json,                                         result: {})
        test_case(:deprovision, 410, broker_partial_json,                                       result: {})
        test_case(:deprovision, 410, broker_malformed_json,                                     result: {})
        test_case(:deprovision, 422, broker_empty_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 422, broker_partial_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 422, broker_malformed_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 422, { error: 'AsyncRequired' }.to_json,                        error: Errors::AsyncRequired)
        test_case(:deprovision, 422, { error: 'ConcurrencyError' }.to_json,                     error: Errors::ConcurrencyError)
        test_common_error_cases(:deprovision)

        test_case(:unbind, 200, broker_partial_json,                                            error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, binding_uri))
        test_case(:unbind, 200, broker_malformed_json,                                          error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, binding_uri))
        test_case(:unbind, 200, broker_empty_json,                                              result: client_result_with_state('succeeded'))
        test_pass_through(:unbind, 200,                                                         expected_state: 'succeeded')
        test_case(:unbind, 201, broker_partial_json,                                            error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_partial_json, binding_uri))
        test_case(:unbind, 201, broker_malformed_json,                                          error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_malformed_json, binding_uri))
        test_case(:unbind, 201, broker_empty_json,                                              error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_empty_json, binding_uri))
        test_case(:unbind, 201, { description: 'error' }.to_json,                               error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, { description: 'error' }.to_json, binding_uri))
        test_case(:unbind, 202, broker_empty_json,                                              result: {})
        test_case(:unbind, 202, broker_malformed_json,                                          error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, binding_uri))
        test_case(:unbind, 202, broker_partial_json,                                            error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, binding_uri))
        test_case(:unbind, 202, with_operation.to_json,                                         result: with_operation)
        test_case(:unbind, 202, with_non_string_operation.to_json,                              error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/operation' of type object did not match the following type: string"))
        test_case(:unbind, 202, with_long_operation.to_json,                                    error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/operation' was not of a maximum string length of 10000"))
        test_case(:unbind, 204, broker_partial_json,                                            error: Errors::ServiceBrokerBadResponse)
        test_case(:unbind, 204, broker_malformed_json,                                          error: Errors::ServiceBrokerBadResponse)
        test_case(:unbind, 204, broker_empty_json,                                              error: Errors::ServiceBrokerBadResponse)
        test_case(:unbind, 409, broker_partial_json,                                            error: Errors::ServiceBrokerBadResponse)
        test_case(:unbind, 409, broker_malformed_json,                                          error: Errors::ServiceBrokerBadResponse)
        test_case(:unbind, 410, broker_empty_json,                                              result: {})
        test_case(:unbind, 410, broker_partial_json,                                            result: {})
        test_case(:unbind, 410, broker_malformed_json,                                          result: {})
        test_case(:unbind, 422, broker_empty_json,                                              error: Errors::ServiceBrokerBadResponse)
        test_case(:unbind, 422, broker_partial_json,                                            error: Errors::ServiceBrokerBadResponse)
        test_case(:unbind, 422, broker_malformed_json,                                          error: Errors::ServiceBrokerBadResponse)
        test_case(:unbind, 422, { error: 'AsyncRequired' }.to_json,                             error: Errors::AsyncRequired)
        test_case(:unbind, 422, { error: 'ConcurrencyError' }.to_json,                          error: Errors::ConcurrencyError)
        test_common_error_cases(:unbind)
        test_case(:update, 200, broker_partial_json,                                            error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:update, 200, broker_malformed_json,                                          error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:update, 200, with_invalid_dashboard_url.to_json,                             error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/dashboard_url' of type object did not match one or more of the following types: string, null"))
        test_case(:update, 200, broker_empty_json,                                              result: client_result_with_state('succeeded'))
        test_case(:update, 200, with_dashboard_url.to_json,                                     result: client_result_with_state('succeeded').merge(with_dashboard_url))
        test_pass_through(:update, 200, with_null_dashboard_url,                                expected_state: 'succeeded')
        test_pass_through(:update, 200,                                                         expected_state: 'succeeded')
        test_case(:update, 201, broker_partial_json,                                            error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_partial_json, instance_uri))
        test_case(:update, 201, broker_malformed_json,                                          error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_malformed_json, instance_uri))
        test_case(:update, 201, broker_empty_json,                                              error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_empty_json, instance_uri))
        test_case(:update, 201, { 'foo' => 'bar' }.to_json,                                     error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, { 'foo' => 'bar' }.to_json, instance_uri))
        test_case(:update, 202, broker_partial_json,                                            error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:update, 202, broker_malformed_json,                                          error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:update, 202, broker_empty_json,                                              result: client_result_with_state('in progress'))
        test_case(:update, 202, broker_non_empty_json,                                          result: client_result_with_state('in progress'))
        test_case(:update, 202, with_operation.to_json,                                         result: client_result_with_state('in progress').merge(with_operation))
        test_case(:update, 202, with_dashboard_url.to_json,                                     result: client_result_with_state('in progress').merge(with_dashboard_url))
        test_pass_through(:update, 202, with_null_dashboard_url,                                expected_state: 'in progress')
        test_case(:update, 202, with_invalid_dashboard_url.to_json,                             error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/dashboard_url' of type object did not match one or more of the following types: string, null"))
        test_case(:update, 202, with_non_string_operation.to_json,                              error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/operation' of type object did not match the following type: string"))
        test_case(:update, 202, with_long_operation.to_json,                                    error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/operation' was not of a maximum string length of 10000"))
        test_pass_through(:update, 202,                                                         expected_state: 'in progress')
        test_case(:update, 204, broker_partial_json,                                            error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 204, broker_malformed_json,                                          error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 204, broker_empty_json,                                              error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 409, broker_empty_json,                                              error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 409, broker_partial_json,                                            error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 410, broker_empty_json,                                              error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 410, broker_partial_json,                                            error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 422, broker_empty_json,                                              error: Errors::ServiceBrokerRequestRejected)
        test_case(:update, 422, broker_partial_json,                                            error: Errors::ServiceBrokerRequestRejected)
        test_case(:update, 422, { error: 'AsyncRequired' }.to_json,                             error: Errors::AsyncRequired)
        test_case(:update, 422, { error: 'MaintenanceInfoConflict' }.to_json,                   error: Errors::MaintenanceInfoConflict)
        test_common_error_cases(:update)

        test_case(:fetch_service_binding, 200, { foo: 'bar' }.to_json,                               result: { 'foo' => 'bar' })
        test_case(:fetch_service_binding, 200, broker_malformed_json,                                error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_malformed_json, binding_uri))
        test_case(:fetch_service_binding, 200, broker_partial_json,                                  error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, binding_uri))
        test_case(:fetch_service_binding, 200, broker_empty_json,                                    result: {})
        test_case(:fetch_service_binding, 200, { parameters: {} }.to_json,                           result: { 'parameters' => {} })
        test_case(:fetch_service_binding, 200, { credentials: {} }.to_json,                          result: { 'credentials' => {} })
        test_case(:fetch_service_binding, 200, { syslog_drain_url: 'url' }.to_json,                  result: { 'syslog_drain_url' =>  'url' })
        test_case(:fetch_service_binding, 200, { route_service_url: 'url' }.to_json,                 result: { 'route_service_url' => 'url' })
        test_case(:fetch_service_binding, 200, with_valid_volume_mounts.to_json,                     result: with_valid_volume_mounts)
        test_case(:fetch_service_binding, 200, { parameters: true }.to_json,                         error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/parameters' of type boolean did not match the following type: object"))
        test_case(:fetch_service_binding, 200, { credentials: 'bla' }.to_json,                       error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/credentials' of type string did not match the following type: object"))
        test_case(:fetch_service_binding, 200, { syslog_drain_url: {} }.to_json,                     error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/syslog_drain_url' of type object did not match the following type: string"))
        test_case(:fetch_service_binding, 200, { route_service_url: {} }.to_json,                    error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/route_service_url' of type object did not match the following type: string"))
        test_case(:fetch_service_binding, 200, { volume_mounts: 'invalid' }.to_json,                 error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts' of type string did not match the following type: array"))
        test_case(:fetch_service_binding, 200, { volume_mounts: ['foo'] }.to_json,                   error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0' of type string did not match the following type: object"))
        test_case(:fetch_service_binding, 200, { volume_mounts: [] }.to_json,                        result: { 'volume_mounts' => [] })
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_device_type.to_json,       error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0/device' of type string did not match the following type: object"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_no_volume_id.to_json,      error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0/device' did not contain a required property of 'volume_id'"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_bad_volume_id.to_json,     error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0/device/volume_id' of type integer did not match the following type: string"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_bad_mount_config.to_json,  error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0/device/mount_config' of type string did not match one or more of the following types: object, null"))
        test_case(:fetch_service_binding, 200, with_valid_volume_mounts_nil_mount_config.to_json,    result: with_valid_volume_mounts_nil_mount_config)
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_no_device.to_json,         error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0' did not contain a required property of 'device'"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_no_device_type.to_json,    error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0' did not contain a required property of 'device_type'"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_bad_device_type.to_json,   error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0/device_type' of type integer did not match the following type: string"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_nil_driver.to_json,        error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0/driver' of type null did not match the following type: string"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_no_driver.to_json,         error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0' did not contain a required property of 'driver'"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_no_mode.to_json,           error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0' did not contain a required property of 'mode'"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_bad_mode_type.to_json,     error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0/mode' value 3 did not match one of the following values: r, rw"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_bad_mode_value.to_json,    error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0/mode' value \"read\" did not match one of the following values: r, rw"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_no_container_dir.to_json,  error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0' did not contain a required property of 'container_dir'"))
        test_case(:fetch_service_binding, 200, with_invalid_volume_mounts_bad_container_dir.to_json, error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(binding_uri, "\nThe property '#/volume_mounts/0/container_dir' of type boolean did not match the following type: string"))
        test_case(:fetch_service_binding, 201, broker_partial_json,                             error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 201, broker_malformed_json,                           error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 201, broker_empty_json,                               error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 201, {}.to_json,                                      error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 204, broker_partial_json,                             error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 204, broker_malformed_json,                           error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 204, broker_empty_json,                               error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 204, {}.to_json,                                      error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 408, {}.to_json,                                      error: Errors::ServiceBrokerApiTimeout, description: broker_timeout_error(binding_uri))
        test_case(:fetch_service_binding, 409, broker_partial_json,                             error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 409, broker_malformed_json,                           error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 409, broker_empty_json,                               error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 410, broker_partial_json,                             error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 410, broker_malformed_json,                           error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 410, broker_empty_json,                               error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 422, broker_partial_json,                             error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 422, broker_malformed_json,                           error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 422, broker_empty_json,                               error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding, 504, {}.to_json,                                      error: Errors::ServiceBrokerBadResponse, description: broker_bad_response_error(binding_uri, 'Status Code: 504 message, Body: {}'))
        test_common_error_cases(:fetch_service_binding)

        test_case(:fetch_service_instance, 200, { foo: 'bar' }.to_json,                         result: { 'foo' => 'bar' })
        test_case(:fetch_service_instance, 200, broker_empty_json,                              result: {})
        test_case(:fetch_service_instance, 200, broker_malformed_json,                          error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:fetch_service_instance, 200, broker_partial_json,                            error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:fetch_service_instance, 200, { service_id: '123' }.to_json,                  result: { 'service_id' => '123' })
        test_case(:fetch_service_instance, 200, { plan_id: '123' }.to_json,                     result: { 'plan_id' => '123' })
        test_case(:fetch_service_instance, 200, { parameters: {} }.to_json,                     result: { 'parameters' => {} })
        test_case(:fetch_service_instance, 200, { dashboard_url: '123' }.to_json,               result: { 'dashboard_url' => '123' })
        test_case(:fetch_service_instance, 200, { service_id: true }.to_json,                   error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/service_id' of type boolean did not match the following type: string"))
        test_case(:fetch_service_instance, 200, { plan_id: true }.to_json,                      error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/plan_id' of type boolean did not match the following type: string"))
        test_case(:fetch_service_instance, 200, { parameters: true }.to_json,                   error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/parameters' of type boolean did not match the following type: object"))
        test_case(:fetch_service_instance, 200, { dashboard_url: true }.to_json,                error: Errors::ServiceBrokerResponseMalformed, description: malformed_response_error(instance_uri, "\nThe property '#/dashboard_url' of type boolean did not match the following type: string"))
        test_case(:fetch_service_instance, 201, broker_partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 201, broker_malformed_json,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 201, broker_empty_json,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 201, {}.to_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 204, broker_partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 204, broker_malformed_json,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 204, broker_empty_json,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 204, {}.to_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 408, {}.to_json,                                     error: Errors::ServiceBrokerApiTimeout, description: broker_timeout_error(instance_uri))
        test_case(:fetch_service_instance, 409, broker_partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 409, broker_malformed_json,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 409, broker_empty_json,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 410, broker_partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 410, broker_malformed_json,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 410, broker_empty_json,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 422, broker_partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 422, broker_malformed_json,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 422, broker_empty_json,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_instance, 504, {}.to_json,                                     error: Errors::ServiceBrokerBadResponse, description: broker_bad_response_error(instance_uri, 'Status Code: 504 message, Body: {}'))
        test_common_error_cases(:fetch_service_instance)

        test_pass_through(:fetch_service_binding_last_operation, 200, broker_body_with_state('succeeded'), expected_state: 'succeeded')
        test_case(:fetch_service_binding_last_operation, 200, { state: 'in progress' }.to_json, result: { 'last_operation' => { 'state' => 'in progress' } })
        test_case(:fetch_service_binding_last_operation, 200, broker_partial_json,                                       error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, binding_last_operation_uri))
        test_case(:fetch_service_binding_last_operation, 200, broker_malformed_json,                                     error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_malformed_json, binding_last_operation_uri), expect_warning: true)
        test_case(:fetch_service_binding_last_operation, 200, broker_empty_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: response_not_understood('succeeded', '', binding_last_operation_uri))
        test_case(:fetch_service_binding_last_operation, 200, broker_body_with_state('unrecognized').to_json,            error: Errors::ServiceBrokerResponseMalformed, description: response_not_understood('succeeded', 'unrecognized', binding_last_operation_uri))
        test_case(:fetch_service_binding_last_operation, 200, broker_body_with_state('succeeded').to_json,               result: client_result_with_state('succeeded'))
        test_case(:fetch_service_binding_last_operation, 200, broker_body_with_state('succeeded').merge('description' => 'a description').to_json, result: client_result_with_state('succeeded', description: 'a description'))
        test_case(:fetch_service_binding_last_operation, 201, broker_partial_json,                                       error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_service_binding_last_operation, 201, broker_malformed_json,                                     error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_service_binding_last_operation, 201, broker_body_with_state('succeeded').to_json,               error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding_last_operation, 202, broker_partial_json,                                       error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_service_binding_last_operation, 202, broker_malformed_json,                                     error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_service_binding_last_operation, 202, broker_body_with_state('succeeded').to_json,               error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding_last_operation, 204, broker_partial_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding_last_operation, 204, broker_malformed_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding_last_operation, 204, broker_empty_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding_last_operation, 409, broker_partial_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding_last_operation, 409, broker_malformed_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding_last_operation, 409, broker_empty_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding_last_operation, 410, broker_empty_json,                                         result: {})
        test_case(:fetch_service_binding_last_operation, 410, broker_partial_json,                                       result: {})
        test_case(:fetch_service_binding_last_operation, 410, broker_malformed_json,                                     result: {})
        test_case(:fetch_service_binding_last_operation, 422, broker_partial_json,                                       error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding_last_operation, 422, broker_malformed_json,                                     error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_service_binding_last_operation, 422, broker_empty_json,                                         error: Errors::ServiceBrokerBadResponse)
        test_common_error_cases(:fetch_service_binding_last_operation)
        # rubocop:enable Layout/LineLength
      end
    end
  end
end
