require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      describe ResponseParser do
        let(:url) { 'my.service-broker.com' }
        subject(:parsed_response) { ResponseParser.new(url).parse(method, path, response) }

        let(:logger) { instance_double(Steno::Logger, warn: nil) }
        before do
          allow(Steno).to receive(:logger).and_return(logger)
        end

        describe 'parse update response' do
          let(:response) do
            VCAP::Services::ServiceBrokers::V2::HttpResponse.new(
              code: code,
              message: message,
              body: body
            )
          end

          let(:message) { nil }
          let(:path) { '/v2/service_instances' }
          let(:body) { '{}' }
          let(:method) { :patch }

          context 'when the status code is 200' do
            let(:code) { 200 }

            context 'the response is partial json response' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'the response is invalid json' do
              let(:body) { 'dfgh' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                expect(logger).to have_received(:warn)
              end
            end

            context 'and the response is an empty JSON object' do
              let(:body) do
                {}.to_json
              end

              it 'returns the response hash' do
                expect(parsed_response).to eq(JSON.parse(body))
              end
            end

            context 'and the response has an invalid key' do
              let(:body) do
                { foo: 'bar' }.to_json
              end

              it 'returns the response hash' do
                expect(parsed_response).to eq(JSON.parse(body))
              end
            end

            context 'and the response has an empty value for last_operation' do
              let(:body) do
                { last_operation: {} }.to_json
              end

              it 'returns the response hash' do
                expect(parsed_response).to eq(JSON.parse(body))
              end
            end

            context 'and the response has an invalid value for last_operation' do
              let(:body) do
                { last_operation: { foo: 'bar' } }.to_json
              end

              it 'returns the response hash' do
                expect(parsed_response).to eq(JSON.parse(body))
              end
            end

            context 'and the response has an invalid state' do
              let(:body) do
                { last_operation: { state: 'foo' } }.to_json
              end

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the response has state `in progress`' do
              let(:body) do
                { last_operation: { state: 'in progress' } }.to_json
              end

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed) do |error|
                  expect(error.to_h['description']).to eq("The service broker response was not understood: expected state was 'succeeded', broker returned 'in progress'.")
                end
              end
            end

            context 'and the response has state `failed`' do
              let(:body) do
                { last_operation: { state: 'failed' } }.to_json
              end

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed) do |error|
                  expect(error.to_h['description']).to eq("The service broker response was not understood: expected state was 'succeeded', broker returned 'failed'.")
                end
              end
            end

            context 'and the response has state `succeeded`' do
              let(:body) do
                { last_operation: { state: 'succeeded' } }.to_json
              end

              it 'returns the response hash' do
                expect(parsed_response).to eq(JSON.parse(body))
              end
            end

            it 'returns response_hash' do
              expect(parsed_response).to eq({})
            end
          end

          context 'when the status code is 201' do
            let(:code) { 201 }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse) do |error|
                expect(error.to_h['description']).to eq("The service broker returned an error for the request to #{url}#{path}. Status Code: #{code} Created, Body: #{body}")
              end
            end
          end

          context 'when the status code is 202' do
            let(:code) { 202 }
            let(:body) do
              {
                dashboard_url: 'url.com/dashboard',
                last_operation: {
                  state: 'in progress',
                  description: 'description',
                },
              }.to_json
            end

            context 'and the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the response is an empty JSON object' do
              let(:body) do
                {}.to_json
              end

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the response has an invalid key' do
              let(:body) do
                { foo: 'bar' }.to_json
              end

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed) do |error|
                  expect(error.to_h['description']).to eq("The service broker response was not understood: #{body}")
                end
              end
            end

            context 'and the response has an empty value for last_operation' do
              let(:body) do
                { last_operation: {} }.to_json
              end

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed) do |error|
                  expect(error.to_h['description']).to eq("The service broker response was not understood: #{body}")
                end
              end
            end

            context 'and the response has an invalid value for last_operation' do
              let(:body) do
                { last_operation: { foo: 'bar' } }.to_json
              end

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed) do |error|
                  expect(error.to_h['description']).to eq("The service broker response was not understood: #{body}")
                end
              end
            end

            context 'and the response has an invalid state' do
              let(:body) do
                { last_operation: { state: 'foo' } }.to_json
              end

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed) do |error|
                  expect(error.to_h['description']).to eq("The service broker response was not understood: expected state was 'in progress', broker returned 'foo'.")
                end
              end
            end

            context 'and the response has state `succeeded`' do
              let(:body) do
                { last_operation: { state: 'succeeded' } }.to_json
              end

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed) do |error|
                  expect(error.to_h['description']).to eq("The service broker response was not understood: expected state was 'in progress', broker returned 'succeeded'.")
                end
              end
            end

            context 'and the response has state `failed`' do
              let(:body) do
                { last_operation: { state: 'failed' } }.to_json
              end

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed) do |error|
                  expect(error.to_h['description']).to eq("The service broker response was not understood: expected state was 'in progress', broker returned 'failed'.")
                end
              end
            end

            context 'and the response has state `in progress`' do
              let(:body) do
                { last_operation: { state: 'in progress' } }.to_json
              end

              it 'returns the response hash' do
                expect(parsed_response).to eq(JSON.parse(body))
              end
            end

            it 'returns the response hash' do
              expect(parsed_response).to eq(JSON.parse(body))
            end
          end

          context 'when the status code is other 2xx' do
            let(:code) { 204 }

            context 'the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end
          end

          context 'when the status code is 3xx' do
            let(:code) { 302 }

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end
          end

          context 'when the status code is 401' do
            let(:code) { 401 }

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerApiAuthenticationFailed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
              end
            end

            it 'raises a ServiceBrokerApiAuthenticationFailed error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
            end
          end

          context 'when the status code is 409' do
            let(:code) { 409 }

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this

              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end
          end

          context 'when the status code is 410' do
            let(:code) { 410 }

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this

              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end
          end

          context 'when the status code is 422' do
            let(:code) { 422 }

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this

              it 'raises a ServiceBrokerRequestRejected error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end

            it 'raises a ServiceBrokerRequestRejected error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
            end

            context 'the response indicates async update is required' do
              let(:body) do
                {
                  error: 'AsyncRequired',
                  description: 'Some error message about needing async'
                }.to_json
              end

              it 'raises an AsyncRequired error' do
                expect { parsed_response }.to raise_error(Errors::AsyncRequired)
              end
            end
          end

          context 'when the status code is other 4xx' do
            let(:code) { 404 }

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerRequestRejected error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end

            it 'raises a ServiceBrokerRequestRejected error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
            end
          end

          context 'when the status code is 5xx' do
            let(:code) { 500 }

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end
          end
        end
      end
    end
  end
end
