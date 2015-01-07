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
            expect(exception.message).to eq('The service broker response was not understood')
            expect(exception.uri).to eq(uri)
            expect(exception.method).to eq(method)
            expect(exception.source).to be(response.body)
          end
        end
      end
    end
  end
end
