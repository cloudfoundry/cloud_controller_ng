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
          let(:description) { 'this is the error description' }

          it 'initializes the base class correctly' do
            exception = ServiceBrokerResponseMalformed.new(uri, method, response, description)
            expect(exception.message).to eq(
              'The service broker returned an invalid response for the request to http://uri.example.com: this is the error description'
            )
            expect(exception.uri).to eq(uri)
            expect(exception.method).to eq(method)
            expect(exception.source).to be(response.body)
          end

          it 'renders a 502 to the user' do
            expect(ServiceBrokerResponseMalformed.new(uri, method, response, description).response_code).to eq 502
          end
        end
      end
    end
  end
end
