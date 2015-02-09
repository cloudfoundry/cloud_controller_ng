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

        describe 'parsing the provision response' do
          let(:response) { instance_double(VCAP::Services::ServiceBrokers::V2::HttpResponse) }
          let(:path) { '/v2/service_instances' }
          let(:body) { '{}' }
          let(:method) { :put }

          before do
            allow(response).to receive(:code).and_return(code)
            allow(response).to receive(:body).and_return(body)
            allow(response).to receive(:message).and_return('message')
          end

          context 'when the status code is 200' do
            let(:code) { 200 }
            let(:body) do
              {
                dashboard_url: 'url.com/dashboard',
                last_operation: {
                  state: state,
                  description: 'description',
                },
              }.to_json
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

            context 'and the state is `succeeded`' do
              let(:state) { 'succeeded' }
              it 'returns response_hash' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                  'last_operation' => {
                    'state' => 'succeeded',
                    'description' => 'description',
                  },
                })
              end
            end

            context 'and the state is `nil`' do
              let(:state) { nil }
              it 'returns response_hash' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                  'last_operation' => {
                    'state' => nil,
                    'description' => 'description',
                  },
                })
              end
            end

            context 'and the state is `in progress`' do
              let(:state) { nil }
              it 'returns response_hash' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                  'last_operation' => {
                    'state' => nil,
                    'description' => 'description',
                  },
                })
              end
            end

            context 'and the state is `failed`' do
              let(:state) { 'failed' }
              it 'returns response_hash' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                  'last_operation' => {
                    'state' => 'failed',
                    'description' => 'description',
                  },
                })
              end
            end

            context 'and the state is not recognized' do
              let(:state) { 'fake-state' }
              it 'raises a ServiceBrokerResponseMalformed' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the request is for a binding' do
              let(:path) { '/v2/service_instances/guid/service_bindings/some-other-guid' }
              let(:state) { 'succeeded' }

              it 'does not propogate a state or description fields if it is present' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                })
              end
            end
          end

          context 'when the status code is 201' do
            let(:code) { 201 }
            let(:body) do
              {
                dashboard_url: 'url.com/dashboard',
                last_operation: {
                  state: state,
                  description: 'description',
                },
              }.to_json
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the state is `succeeded`' do
              let(:state) { 'succeeded' }
              it 'returns response_hash' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                  'last_operation' => {
                    'state' => 'succeeded',
                    'description' => 'description',
                  },
                })
              end
            end

            context 'and the state is nil' do
              let(:state) { nil }
              it 'returns response_hash' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                  'last_operation' => {
                    'state' => nil,
                    'description' => 'description',
                  },
                })
              end
            end

            context 'and the state is `failed`' do
              let(:state) { 'failed' }

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the state is `in progress`' do
              let(:state) { 'in progress' }

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the state is unrecognized' do
              let(:state) { 'fake-state' }

              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the request is for bindings' do
              let(:state) { 'whatever' }
              let(:path) { '/v2/service_instances/guid/service_bindings/some-other-guid' }

              it 'does not propagade state and description fields' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                })
              end
            end
          end

          context 'when the status code is 202' do
            let(:code) { 202 }
            let(:body) do
              {
                dashboard_url: 'url.com/dashboard',
                last_operation: {
                  state: state,
                  description: 'description',
                },
              }.to_json
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the state is `succeeded`' do
              let(:state) { 'succeeded' }

              it 'should raise ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the state is `failed`' do
              let(:state) { 'failed' }

              it 'should raise ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the state is `in progress`' do
              let(:state) { 'in progress' }

              it 'should return the response_hash' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                  'last_operation' => {
                    'state' => 'in progress',
                    'description' => 'description',
                  },
                })
              end
            end

            context 'and the state is nil' do
              let(:state) { nil }

              it 'should raise ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the state is unrecognized' do
              let(:state) { :unrecognized }

              it 'should raise ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the request is for bindings' do
              let(:state) { 'in progress' }
              let(:path) { '/v2/service_instances/guid/service_bindings/some-other-guid' }

              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
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
              it 'raises a ServiceBrokerConflict error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerConflict)
              end
            end

            it 'raises a ServiceBrokerConflict error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerConflict)
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
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'when the error field is `AsyncRequired`' do
              let(:body) { { error: 'AsyncRequired' }.to_json }
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
