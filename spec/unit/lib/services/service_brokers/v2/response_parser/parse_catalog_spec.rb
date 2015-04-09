require 'spec_helper'
require 'unit/lib/services/service_brokers/v2/response_parser/shared_examples'

module VCAP::Services
  module ServiceBrokers
    module V2
      describe ResponseParser do
        let(:url) { 'my.service-broker.com' }
        subject(:parsed_response) { ResponseParser.new(url).parse_catalog(path, response) }

        let(:logger) { instance_double(Steno::Logger, warn: nil) }
        before do
          allow(Steno).to receive(:logger).and_return(logger)
        end

        describe 'parsing the catalog' do
          let(:response) { instance_double(VCAP::Services::ServiceBrokers::V2::HttpResponse) }
          let(:path) { '/v2/service_instances' }
          let(:code) { 200 }
          let(:method) { :get }
          let(:body) { body_hash.to_json }
          let(:body_hash) do
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

          before do
            allow(response).to receive(:code).and_return(code)
            allow(response).to receive(:body).and_return(body)
            allow(response).to receive(:message).and_return('message')
          end

          context 'when the response is a 200 and a valid JSON object' do
            it 'returns the response hash' do
              expect(parsed_response).to eq(body_hash)
            end
          end

          context 'when the response is a 201 and an valid JSON object' do
            let(:code) { 201 }

            it 'raises a bad response error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end
          end

          context 'when the response is a 201 and an invalid JSON object' do
            let(:code) { 201 }
            let(:body) { 'Not JSON' }

            it 'raises a malformed response error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
            end
          end

          context 'when the response is a 2xx (excluding 200, 201, 202)' do
            let(:code) { 299 }

            it 'raises a bad response error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end
          end

          it_should_behave_like 'a parser that handles error codes'
        end
      end
    end
  end
end
