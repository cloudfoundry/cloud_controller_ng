require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      RSpec.describe 'ResponseParser' do
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

        def self.broker_partial_json
          '""'
        end

        def self.broker_malformed_json
          'shenanigans'
        end

        def self.broker_empty_json
          '{}'
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

        def self.client_result_with_state(state, description: nil)
          response_body = {
            'last_operation' => {
              'state' => state,
            }
          }

          response_body['last_operation']['description'] = description if description
          response_body
        end

        def self.response_not_understood(expected_state, actual_state)
          actual_state = actual_state ? "'#{actual_state}'" : 'null'
          'The service broker returned an invalid response for the request to service-broker.com/v2/service_instances/GUID: ' \
          "expected state was '#{expected_state}', broker returned #{actual_state}."
        end

        def self.invalid_json_error(body, uri)
          "The service broker returned an invalid response for the request to #{uri}: " \
          "expected valid JSON object in body, broker returned '#{body}'"
        end

        def self.broker_returned_an_error(status, body, uri)
          "The service broker returned an invalid response for the request to #{uri}. " \
          "Status Code: #{status} message, Body: #{body}"
        end

        def self.invalid_volume_mounts_error(body, uri)
          "The service broker returned an invalid response for the request to #{uri}: " \
          "expected \"volume_mounts\" key to contain an array of JSON objects in body, broker returned '#{body}'"
        end

        def self.volume_mounts_not_required_error(uri)
          "The service broker returned an invalid response for the request to #{uri}: " \
          'The service is attempting to supply volume mounts from your application, but is not registered as a volume mount service. ' \
          'Please contact the service provider.'
        end

        def self.with_valid_volume_mounts
          {
            'volume_mounts' => [{}]
          }
        end

        def self.with_invalid_volume_mounts
          {
            'volume_mounts' => {}
          }
        end

        def self.without_volume_mounts
          {
          }
        end

        # rubocop:disable Metrics/LineLength
        test_case(:provision, 200, broker_partial_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:provision, 200, broker_malformed_json,                                       error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:provision, 200, broker_empty_json,                                           result: client_result_with_state('succeeded'))
        test_case(:provision, 200, with_dashboard_url.to_json,                                  result: client_result_with_state('succeeded').merge(with_dashboard_url))
        test_pass_through(:provision, 200, with_dashboard_url,                                  expected_state: 'succeeded')
        test_case(:provision, 201, broker_partial_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:provision, 201, broker_malformed_json,                                       error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:provision, 201, broker_empty_json,                                           result: client_result_with_state('succeeded'))
        test_case(:provision, 201, with_dashboard_url.to_json,                                  result: client_result_with_state('succeeded').merge(with_dashboard_url))
        test_pass_through(:provision, 201, with_dashboard_url,                                  expected_state: 'succeeded')
        test_case(:provision, 202, broker_partial_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:provision, 202, broker_malformed_json,                                       error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:provision, 202, broker_empty_json,                                           result: client_result_with_state('in progress'))
        test_case(:provision, 202, broker_non_empty_json,                                       result: client_result_with_state('in progress'))
        test_case(:provision, 202, with_dashboard_url.to_json,                                  result: client_result_with_state('in progress').merge(with_dashboard_url))
        test_pass_through(:provision, 202, with_dashboard_url,                                  expected_state: 'in progress')
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
        test_common_error_cases(:provision)

        test_case(:bind,      200, broker_partial_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, binding_uri))
        test_case(:bind,      200, broker_malformed_json,                                       error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, binding_uri))
        test_case(:bind,      200, broker_empty_json,                                           result: client_result_with_state('succeeded'))
        test_case(:bind,      200, with_credentials.to_json,                                    result: client_result_with_state('succeeded').merge(with_credentials))
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
        test_pass_through(:bind, 200, with_credentials,                                         expected_state: 'succeeded')

        test_case(:bind,      201, broker_partial_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, binding_uri))
        test_case(:bind,      201, broker_malformed_json,                                       error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, binding_uri))
        test_case(:bind,      201, broker_empty_json,                                           result: client_result_with_state('succeeded'))
        test_case(:bind,      201, with_credentials.to_json,                                    result: client_result_with_state('succeeded').merge(with_credentials))
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

        test_case(:bind,      202, broker_empty_json,                                           error: Errors::ServiceBrokerBadResponse)
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
        test_case(:bind,      422, { error: 'AsyncRequired' }.to_json,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:bind,      422, { error: 'RequiresApp' }.to_json,                            error: Errors::AppRequired)
        test_common_error_cases(:bind)

        test_case(:fetch_state, 200, broker_partial_json,                                       error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:fetch_state, 200, broker_malformed_json,                                     error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_malformed_json, instance_uri), expect_warning: true)
        test_case(:fetch_state, 200, broker_empty_json,                                         error: Errors::ServiceBrokerResponseMalformed, description: response_not_understood('succeeded', ''))
        test_case(:fetch_state, 200, broker_body_with_state('unrecognized').to_json,            error: Errors::ServiceBrokerResponseMalformed, description: response_not_understood('succeeded', 'unrecognized'))
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
        test_common_error_cases(:deprovision)

        test_case(:unbind, 200, broker_partial_json,                                            error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, binding_uri))
        test_case(:unbind, 200, broker_malformed_json,                                          error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, binding_uri))
        test_case(:unbind, 200, broker_empty_json,                                              result: client_result_with_state('succeeded'))
        test_pass_through(:unbind, 200,                                                         expected_state: 'succeeded')
        test_case(:unbind, 201, broker_partial_json,                                            error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_partial_json, binding_uri))
        test_case(:unbind, 201, broker_malformed_json,                                          error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_malformed_json, binding_uri))
        test_case(:unbind, 201, broker_empty_json,                                              error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_empty_json, binding_uri))
        test_case(:unbind, 201, { description: 'error' }.to_json,                               error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, { description: 'error' }.to_json, binding_uri))
        test_case(:unbind, 202, broker_empty_json,                                              error: Errors::ServiceBrokerBadResponse)
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
        test_case(:unbind, 422, { error: 'AsyncRequired' }.to_json,                             error: Errors::ServiceBrokerBadResponse)
        test_common_error_cases(:unbind)

        test_case(:update, 200, broker_partial_json,                                            error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:update, 200, broker_malformed_json,                                          error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:update, 200, broker_empty_json,                                              result: client_result_with_state('succeeded'))
        test_pass_through(:update, 200,                                                         expected_state: 'succeeded')
        test_case(:update, 201, broker_partial_json,                                            error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_partial_json, instance_uri))
        test_case(:update, 201, broker_malformed_json,                                          error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_malformed_json, instance_uri))
        test_case(:update, 201, broker_empty_json,                                              error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, broker_empty_json, instance_uri))
        test_case(:update, 201, { 'foo' => 'bar' }.to_json,                                     error: Errors::ServiceBrokerBadResponse, description: broker_returned_an_error(201, { 'foo' => 'bar' }.to_json, instance_uri))
        test_case(:update, 202, broker_partial_json,                                            error: Errors::ServiceBrokerResponseMalformed, description: invalid_json_error(broker_partial_json, instance_uri))
        test_case(:update, 202, broker_malformed_json,                                          error: Errors::ServiceBrokerResponseMalformed, expect_warning: true, description: invalid_json_error(broker_malformed_json, instance_uri))
        test_case(:update, 202, broker_empty_json,                                              result: client_result_with_state('in progress'))
        test_case(:update, 202, broker_non_empty_json,                                          result: client_result_with_state('in progress'))
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
        test_common_error_cases(:update)
        # rubocop:enable Metrics/LineLength
      end
    end
  end
end
