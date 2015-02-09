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

        describe 'parsing the state fetch response' do
          subject(:parsed_response) { ResponseParser.new(url).parse_fetch_state(method, path, response) }
          let(:response) { instance_double(VCAP::Services::ServiceBrokers::V2::HttpResponse) }
          let(:path) { '/v2/service_instances' }
          let(:body) { '{}' }

          before do
            allow(response).to receive(:code).and_return(code)
            allow(response).to receive(:body).and_return(body)
            allow(response).to receive(:message).and_return('message')
          end

          context 'when the status code is 200' do
            let(:code) { 200 }

            let(:method) { :get }
            let(:body) do
              {
                dashboard_url: 'url.com/dashboard',
                last_operation: {
                  state: state,
                  description: 'description',
                },
              }.to_json
            end

            context 'and the state is recognized' do
              let(:state) { 'in progress' }

              it 'returns response_hash' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                  'last_operation' => {
                    'state' => 'in progress',
                    'description' => 'description',
                  },
                })
              end
            end

            context 'and the state is not recgonized' do
              let(:state) { 'fake-state' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the last_operation is not present' do
              let(:body) { { state: 'state-in-incorrect-location' }.to_json }
              it 'raises ServiceBrokerResponseMalformed' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end
          end

          context 'when the status code is 201' do
            let(:code) { 201 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end
          end

          context 'when the status code is 202' do
            let(:code) { 202 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end
          end

          context 'when the status code is other 2xx' do
            let(:code) { 204 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 3xx' do
            let(:code) { 302 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 401' do
            let(:code) { 401 }
            let(:method) { :get }
            it 'raises a ServiceBrokerApiAuthenticationFailed error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerApiAuthenticationFailed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
              end
            end
          end

          context 'when the status code is 409' do
            let(:code) { 409 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 410' do
            let(:code) { 410 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 422' do
            let(:code) { 422 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is other 4xx' do
            let(:code) { 404 }
            let(:method) { :get }

            it 'raises a ServiceBrokerRequestRejected error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerRequestRejected error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end
          end

          context 'when the status code is 5xx' do
            let(:code) { 500 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end
        end
      end
    end
  end
end
