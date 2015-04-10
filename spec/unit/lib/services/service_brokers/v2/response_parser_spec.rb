require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      describe 'ResponseParser' do
        ::RSpec::Matchers.define :have_description do |expected|
          match do |actual|
            actual.to_h['description'] == expected
          end
        end

        def get_method_and_path(operation)
          case operation
          when :provision
            method = :parse_provision_or_bind
            path = '/v2/service_instances/GUID'
          when :deprovision
            method = :parse_deprovision_or_unbind
            path = '/v2/service_instances/GUID'
          when :update
            method = :parse_update
            path = '/v2/service_instances/GUID'
          when :bind
            method = :parse_provision_or_bind
            path = '/v2/service_instances/GUID/service_bindings/BINDING_GUID'
          when :unbind
            method = :parse_deprovision_or_unbind
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

        def self.test_case(operation, code, body, opts={})
          expect_warning = !!opts[:expect_warning]
          description = opts[:description]
          result = opts[:result]
          error = opts[:error]

          context "making a #{operation} request that returns code #{code} and body #{body}" do
            let(:response_parser) { ResponseParser.new('service-broker.com') }
            let(:fake_response) { instance_double(VCAP::Services::ServiceBrokers::V2::HttpResponse) }
            let(:body) { body }
            let(:logger) { instance_double(Steno::Logger, warn: nil) }

            before do
              @method, @path = get_method_and_path(operation)
              allow(fake_response).to receive(:code).and_return(code)
              allow(fake_response).to receive(:body).and_return(body)
              allow(fake_response).to receive(:message).and_return('message')
              allow(Steno).to receive(:logger).and_return(logger)
            end

            if error
              it "raises a #{error} error" do
                expect { response_parser.send(@method, @path, fake_response) }.to raise_error(error) do |e|
                  expect(e.to_h['description']).to eq(description) if description
                end
                expect(logger).to have_received(:warn) if expect_warning
              end
            else
              it 'returns the parsed response' do
                expect(response_parser.send(@method, @path, fake_response)).to eq(result)
              end
            end
          end
        end

        empty_body = '{}'
        partial_json = '""'
        malformed_json = 'shenanigans'
        with_dashboard_url = {
          'dashboard_url' => 'url.com/foo'
        }
        valid_catalog = {
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

        def self.base_async_body(state)
          {
            'last_operation' => {
              'state' => state,
            },
          }
        end

        def self.response_not_understood(expected_state, actual_state)
          actual_state = (actual_state) ? "'#{actual_state}'" : 'null'
          'The service broker returned an invalid response for the request to service-broker.com/v2/service_instances/GUID: ' + \
          "expected state was '#{expected_state}', broker returned #{actual_state}."
        end

        def self.invalid_json_error(body)
          'The service broker returned an invalid response for the request to service-broker.com/v2/service_instances/GUID: ' + \
          "expected valid JSON object in body, broker returned '#{body}'"
        end

        def self.broker_returned_an_error(status, body)
          'The service broker returned an invalid response for the request to service-broker.com/v2/service_instances/GUID. ' + \
          "Status Code: #{status} message, Body: #{body}"
        end

        test_case(:provision, 200, partial_json,                        error: Errors::ServiceBrokerResponseMalformed,
                                                                        description: invalid_json_error(partial_json))
        test_case(:provision, 200, malformed_json,                      error: Errors::ServiceBrokerResponseMalformed,
                                                                        expect_warning: true,
                                                                        description: invalid_json_error(malformed_json))
        test_case(:provision, 200, empty_body,                          result: base_async_body('succeeded'))
        test_case(:provision, 200, with_dashboard_url.to_json,          result: base_async_body('succeeded').merge(with_dashboard_url))
        test_case(:provision, 201, malformed_json,                      error: Errors::ServiceBrokerResponseMalformed,
                                                                        expect_warning: true,
                                                                        description: invalid_json_error(malformed_json))
        test_case(:provision, 201, empty_body,                          result: base_async_body('succeeded'))
        test_case(:provision, 201, with_dashboard_url.to_json,          result: base_async_body('succeeded').merge(with_dashboard_url))
        test_case(:provision, 202, malformed_json,                      error: Errors::ServiceBrokerResponseMalformed,
                                                                        expect_warning: true,
                                                                        description: invalid_json_error(malformed_json))
        test_case(:provision, 202, empty_body,                          result: base_async_body('in progress'))
        test_case(:provision, 202, with_dashboard_url.to_json,          result: base_async_body('in progress').merge(with_dashboard_url))

        test_case(:bind,      202, empty_body,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 204, empty_body,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 204, partial_json,                        error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 302, empty_body,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 302, partial_json,                        error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 401, empty_body,                          error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:provision, 401, partial_json,                        error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:provision, 404, empty_body,                          error: Errors::ServiceBrokerRequestRejected)
        test_case(:provision, 404, partial_json,                        error: Errors::ServiceBrokerRequestRejected)
        test_case(:provision, 409, empty_body,                          error: Errors::ServiceBrokerConflict)
        test_case(:provision, 409, partial_json,                        error: Errors::ServiceBrokerConflict)
        test_case(:provision, 410, empty_body,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 410, partial_json,                        error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 422, empty_body,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 422, partial_json,                        error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 422, { error: 'AsyncRequired' }.to_json,  error: Errors::AsyncRequired)
        test_case(:provision, 500, empty_body,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 500, partial_json,                        error: Errors::ServiceBrokerBadResponse)

        test_case(:fetch_state, 200, partial_json,                            error: Errors::ServiceBrokerResponseMalformed,
                                                                              description: invalid_json_error(partial_json))
        test_case(:fetch_state, 200, malformed_json,                          error: Errors::ServiceBrokerResponseMalformed,
                                                                              expect_warning: true,
                                                                              description: invalid_json_error(malformed_json))
        test_case(:fetch_state, 200, base_async_body('unrecognized').to_json, error: Errors::ServiceBrokerResponseMalformed,
                                                                              description: response_not_understood('succeeded', 'unrecognized'))
        test_case(:fetch_state, 200, base_async_body('succeeded').to_json,    result: base_async_body('succeeded'))
        test_case(:fetch_state, 410, empty_body,                              result: {})
        test_case(:fetch_state, 410, partial_json,                            result: {})

        test_case(:fetch_state, 201, partial_json,                            error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_state, 201, base_async_body('succeeded').to_json,    error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 202, partial_json,                            error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_state, 202, base_async_body('succeeded').to_json,    error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 204, empty_body,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 204, partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 301, empty_body,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 301, partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 401, empty_body,                              error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:fetch_state, 401, partial_json,                            error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:fetch_state, 404, empty_body,                              error: Errors::ServiceBrokerRequestRejected)
        test_case(:fetch_state, 404, partial_json,                            error: Errors::ServiceBrokerRequestRejected)
        test_case(:fetch_state, 409, empty_body,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 409, partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 422, empty_body,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 422, partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 500, empty_body,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_state, 500, partial_json,                            error: Errors::ServiceBrokerBadResponse)

        test_case(:fetch_catalog, 200, valid_catalog.to_json,                 result: valid_catalog)
        test_case(:fetch_catalog, 201, valid_catalog.to_json,                 error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 201, partial_json,                          error: Errors::ServiceBrokerResponseMalformed)
        test_case(:fetch_catalog, 204, valid_catalog.to_json,                 error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 301, empty_body,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 301, partial_json,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 401, empty_body,                            error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:fetch_catalog, 401, partial_json,                          error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:fetch_catalog, 404, empty_body,                            error: Errors::ServiceBrokerRequestRejected)
        test_case(:fetch_catalog, 404, partial_json,                          error: Errors::ServiceBrokerRequestRejected)
        test_case(:fetch_catalog, 409, empty_body,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 409, partial_json,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 422, empty_body,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 422, partial_json,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 500, empty_body,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:fetch_catalog, 500, partial_json,                          error: Errors::ServiceBrokerBadResponse)

        test_case(:deprovision, 200, partial_json,                            error: Errors::ServiceBrokerResponseMalformed,
                                                                              description: invalid_json_error(partial_json))
        test_case(:deprovision, 200, malformed_json,                          error: Errors::ServiceBrokerResponseMalformed,
                                                                              expect_warning: true,
                                                                              description: invalid_json_error(malformed_json))
        test_case(:deprovision, 200, empty_body,                              result: base_async_body('succeeded'))

        test_case(:deprovision, 201, { description: 'error' }.to_json,        error: Errors::ServiceBrokerBadResponse,
                                                                              description: broker_returned_an_error(201, { description: 'error' }.to_json))
        test_case(:deprovision, 202, malformed_json,                          error: Errors::ServiceBrokerResponseMalformed,
                                                                              expect_warning: true,
                                                                              description: invalid_json_error(malformed_json))
        test_case(:deprovision, 202, empty_body,                              result: base_async_body('in progress'))

        test_case(:unbind,      202, empty_body,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 204, empty_body,                              result: {})
        test_case(:deprovision, 204, partial_json,                            result: {})
        test_case(:deprovision, 302, empty_body,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 302, partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 401, empty_body,                              error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:deprovision, 401, partial_json,                            error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:deprovision, 404, empty_body,                              error: Errors::ServiceBrokerRequestRejected)
        test_case(:deprovision, 404, partial_json,                            error: Errors::ServiceBrokerRequestRejected)
        test_case(:deprovision, 409, empty_body,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 409, partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 410, empty_body,                              result: {})
        test_case(:deprovision, 410, partial_json,                            result: {})
        test_case(:deprovision, 422, empty_body,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 422, partial_json,                            error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 422, { error: 'AsyncRequired' }.to_json,      error: Errors::AsyncRequired)
        test_case(:deprovision, 500, empty_body,                              error: Errors::ServiceBrokerBadResponse)
        test_case(:deprovision, 500, partial_json,                            error: Errors::ServiceBrokerBadResponse)

        test_case(:update, 200, partial_json,                                 error: Errors::ServiceBrokerResponseMalformed,
                                                                              description: invalid_json_error(partial_json))
        test_case(:update, 200, malformed_json,                               error: Errors::ServiceBrokerResponseMalformed,
                                                                              expect_warning: true,
                                                                              description: invalid_json_error(malformed_json))
        test_case(:update, 200, empty_body,                                   result: base_async_body('succeeded'))
        test_case(:update, 200, { foo: 'bar' }.to_json,                       result: base_async_body('succeeded').merge({ 'foo' => 'bar' }))
        test_case(:update, 201, { 'foo' => 'bar' }.to_json,                   error: Errors::ServiceBrokerBadResponse,
                                                                              description: broker_returned_an_error(201, { 'foo' => 'bar' }.to_json))
        test_case(:update, 202, malformed_json,                               error: Errors::ServiceBrokerResponseMalformed,
                                                                              expect_warning: true,
                                                                              description: invalid_json_error(malformed_json))
        test_case(:update, 202, empty_body,                                   result: base_async_body('in progress'))
        test_case(:update, 202, { foo: 'bar' }.to_json,                       result: base_async_body('in progress').merge({ 'foo' => 'bar' }))

        test_case(:update, 204, empty_body,                                   error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 204, partial_json,                                 error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 302, empty_body,                                   error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 302, partial_json,                                 error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 401, empty_body,                                   error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:update, 401, partial_json,                                 error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:update, 404, empty_body,                                   error: Errors::ServiceBrokerRequestRejected)
        test_case(:update, 404, partial_json,                                 error: Errors::ServiceBrokerRequestRejected)
        test_case(:update, 409, empty_body,                                   error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 409, partial_json,                                 error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 410, empty_body,                                   error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 410, partial_json,                                 error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 422, empty_body,                                   error: Errors::ServiceBrokerRequestRejected)
        test_case(:update, 422, partial_json,                                 error: Errors::ServiceBrokerRequestRejected)
        test_case(:update, 422, { error: 'AsyncRequired' }.to_json,           error: Errors::AsyncRequired)
        test_case(:update, 500, empty_body,                                   error: Errors::ServiceBrokerBadResponse)
        test_case(:update, 500, partial_json,                                 error: Errors::ServiceBrokerBadResponse)
      end
    end
  end
end
