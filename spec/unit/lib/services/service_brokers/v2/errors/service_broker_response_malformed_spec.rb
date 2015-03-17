require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        describe ServiceBrokerResponseMalformed do
          let(:uri) { 'http://uri.example.com' }
          let(:method) { 'POST' }
          let(:error) { StandardError.new }
          let(:response_body) { 'foo' }
          let(:response) { double(code: 200, reason: 'OK', body: response_body) }

          it 'initializes the base class correctly' do
            exception = ServiceBrokerResponseMalformed.new(uri, method, response)
            expect(exception.message).to eq('The service broker returned an invalid response for the request to http://uri.example.com: ' \
              "expected valid JSON object in body, broker returned 'foo'")
            expect(exception.uri).to eq(uri)
            expect(exception.method).to eq(method)
            expect(exception.source).to be(response.body)
          end

          context 'with an invalid JSON body' do
            it 'parses an invalid last operation state correctly' do
              exception = ServiceBrokerResponseMalformed.new(uri, method, response)
              expect(exception.message).to eq(('The service broker returned an invalid response for the request to http://uri.example.com: ' \
               "expected valid JSON object in body, broker returned 'foo'"))
            end
          end

          context 'with a valid JSON body' do
            let(:response_body) do
              {
                'last_operation' => {
                  'state' => 'foo'
                }
              }.to_json
            end

            it 'parses an invalid last operation state correctly' do
              exception = ServiceBrokerResponseMalformed.new(uri, method, response)
              expect(exception.message).to eq(('The service broker returned an invalid response for the request to http://uri.example.com: ' \
                "expected state was 'succeeded', broker returned 'foo'"))
            end
          end

          it 'renders a 502 to the user' do
            expect(ServiceBrokerResponseMalformed.new(uri, method, response).response_code).to eq 502
          end
        end
      end
    end
  end
end
