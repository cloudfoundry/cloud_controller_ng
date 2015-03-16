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
            method = :put
            path = '/v2/service_instances/GUID'
          when :deprovision
            method = :delete
            path = '/v2/service_instances/GUID'
          when :update
            method = :patch
            path = '/v2/service_instances/GUID'
          when :bind
            method = :put
            path = '/v2/service_instances/GUID/service_bindings/BINDING_GUID'
          when :unbind
            method = :delete
            path = '/v2/service_instances/GUID/service_bindings/BINDING_GUID'
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
                expect { response_parser.parse(@method, @path, fake_response) }.to raise_error(error) do |e|
                  expect(e.to_h['description']).to eq(description) if description
                end
                expect(logger).to have_received(:warn) if expect_warning
              end
            else
              it 'returns the parsed response' do
                expect(response_parser.parse(@method, @path, fake_response)).to eq(result)
              end
            end
          end
        end

        empty_body = '{}'
        partial_json = '""'
        malformed_json = 'shenanigans'
        def self.async_body(state)
          {
            'dashboard_url' => 'url.com/dashboard',
            'last_operation' => {
              'state' => state,
              'description' => 'description',
            },
          }
        end

        def self.response_not_understood(expected_state, actual_state)
          actual_state = (actual_state) ? "'#{actual_state}'" : 'null'
          "The service broker response was not understood: expected state was '#{expected_state}', broker returned #{actual_state}."
        end

        def self.verify_response(desired_response, error)
          error.to_h['description'] == desired_response
        end

        # parse provision or bind spec
        test_case(:provision, 200, partial_json,                        error: Errors::ServiceBrokerResponseMalformed)
        test_case(:provision, 200, malformed_json,                      error: Errors::ServiceBrokerResponseMalformed,
                                                                        expect_warning: true)
        test_case(:provision, 200, async_body('succeeded').to_json,     result: async_body('succeeded'))
        test_case(:provision, 200, async_body(nil).to_json,             result: async_body(nil))
        test_case(:provision, 200, async_body('in progress').to_json,   result: async_body('in progress'))
        test_case(:provision, 200, async_body('failed').to_json,        result: async_body('failed'))
        test_case(:provision, 200, async_body('fake-state').to_json,    error: Errors::ServiceBrokerResponseMalformed)
        test_case(:provision, 201, malformed_json,                      error: Errors::ServiceBrokerResponseMalformed,
                                                                        expect_warning: true)
        test_case(:provision, 201, async_body('succeeded').to_json,     result: async_body('succeeded'))
        test_case(:provision, 201, async_body(nil).to_json,             result: async_body(nil))
        test_case(:provision, 201, async_body('in progress').to_json,   error: Errors::ServiceBrokerResponseMalformed,
                                                                        description: response_not_understood('succeeded', 'in progress'))
        test_case(:provision, 201, async_body('failed').to_json,        error: Errors::ServiceBrokerResponseMalformed,
                                                                        descriptipn: response_not_understood('succeeded', 'failed'))
        test_case(:provision, 201, async_body('fake-state').to_json,    error: Errors::ServiceBrokerResponseMalformed,
                                                                        description: response_not_understood('succeeded', 'fake-state'))
        test_case(:provision, 202, malformed_json,                      error: Errors::ServiceBrokerResponseMalformed,
                                                                        expect_warning: true)
        test_case(:provision, 202, async_body('succeeded').to_json,     error: Errors::ServiceBrokerResponseMalformed,
                                                                        description: response_not_understood('in progress', 'succeeded'))
        test_case(:provision, 202, async_body(nil).to_json,             error: Errors::ServiceBrokerResponseMalformed,
                                                                        description: response_not_understood('in progress', nil))
        test_case(:provision, 202, async_body('in progress').to_json,   result: async_body('in progress'))
        test_case(:provision, 202, async_body('failed').to_json,        error: Errors::ServiceBrokerResponseMalformed,
                                                                        description: response_not_understood('in progress', 'failed'))
        test_case(:provision, 202, async_body('fake-state').to_json,    error: Errors::ServiceBrokerResponseMalformed,
                                                                        description: response_not_understood('in progress', 'fake-state'))
        test_case(:bind,      202, async_body('in progress').to_json,   error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 204, empty_body,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 204, partial_json,                        error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 302, empty_body,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 302, partial_json,                        error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 401, empty_body,                          error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:provision, 401, partial_json,                        error: Errors::ServiceBrokerApiAuthenticationFailed)
        test_case(:provision, 409, empty_body,                          error: Errors::ServiceBrokerConflict)
        test_case(:provision, 409, partial_json,                        error: Errors::ServiceBrokerConflict)
        test_case(:provision, 410, empty_body,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 410, partial_json,                        error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 422, empty_body,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 422, partial_json,                        error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 422, { error: 'AsyncRequired' }.to_json,  error: Errors::AsyncRequired)
        test_case(:provision, 404, empty_body,                          error: Errors::ServiceBrokerRequestRejected)
        test_case(:provision, 404, partial_json,                        error: Errors::ServiceBrokerRequestRejected)
        test_case(:provision, 500, empty_body,                          error: Errors::ServiceBrokerBadResponse)
        test_case(:provision, 500, partial_json,                        error: Errors::ServiceBrokerBadResponse)
      end
    end
  end
end
