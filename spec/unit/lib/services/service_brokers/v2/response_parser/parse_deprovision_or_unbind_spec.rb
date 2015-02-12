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

        describe 'parsing a DELETE response' do
          let(:response) { instance_double(VCAP::Services::ServiceBrokers::V2::HttpResponse) }
          let(:path) { '/v2/service_instances' }
          let(:body) { {}.to_json }
          let(:method) { :delete }

          before do
            allow(response).to receive(:code).and_return(code)
            allow(response).to receive(:body).and_return(body)
            allow(response).to receive(:message).and_return('message')
          end

          context 'when the status code is 200' do
            let(:code) { 200 }

            it 'should be ok' do
              expect(parsed_response).to eq({})
            end

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

            context 'the state is "succeeded"' do
              let(:body) do
                {
                  last_operation: {
                    state: 'succeeded',
                  }
                }.to_json
              end

              it 'returns response_hash' do
                expect(parsed_response).to eq({
                  'last_operation' => {
                    'state' => 'succeeded'
                  }
                })
              end
            end

            context 'the state is not specified' do
              it 'returns response_hash' do
                expect(parsed_response).to eq({})
              end
            end

            context 'the state is not "succeeded"' do
              let(:body) do
                {
                  last_operation: {
                    state: 'blarg',
                  }
                }.to_json
              end

              context 'when the path indicates a unbind request' do
                let(:path) { '/v2/service_instances/valid-service-instance-guid/service_bindings/binding-guid' }

                it 'returns the response hash' do
                  expect(parsed_response).to eq({
                    'last_operation' => {
                      'state' => 'blarg',
                    },
                  })
                end
              end

              context 'when the path indicates a deprovision request' do
                it 'raises a ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end
            end
          end

          context 'when the status code is 201' do
            let(:code) { 201 }

            context 'the response is not a valid json object' do
              let(:body) { '""' }

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end
          end

          context 'when the status code is 202' do
            let(:code) { 202 }
            let(:body) do
              {
                  last_operation: {
                    state: 'in progress',
                  }
              }.to_json
            end

            it 'returns the parsed response with last_operation' do
              expect(parsed_response).to eq({
                  'last_operation' => {
                    'state' => 'in progress'
                  }
                })
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' }

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end
          end

          context 'when the status code is other 2xx (excluding 200, 201, 202)' do
            let(:code) { 204 }

            context 'the response is not a valid json object' do
              let(:body) { '""' }

              it 'returns an empty hash' do
                expect(parsed_response).to eq({})
              end
            end

            it 'returns an empty hash' do
              expect(parsed_response).to eq({})
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

              it 'returns nil and logs a warning' do
                expect(parsed_response).to be_nil
                expect(logger).to have_received(:warn)
              end
            end

            it 'returns nil and logs a warning' do
              expect(parsed_response).to be_nil
              expect(logger).to have_received(:warn)
            end
          end

          context 'when the status code is 422' do
            let(:code) { 422 }

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'when the error field is `AsyncRequired`' do
              let(:body) { { error: 'AsyncRequired' }.to_json }

              it 'raises an AsyncRequired error' do
                expect { parsed_response }.to raise_error(Errors::AsyncRequired)
              end
            end

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
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
