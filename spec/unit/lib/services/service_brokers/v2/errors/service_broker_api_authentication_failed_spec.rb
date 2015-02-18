require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        describe 'ServiceBrokerAuthenticationFailed' do
          let(:uri) { 'http://uri.example.com' }
          let(:method) { 'POST' }
          let(:error) { StandardError.new }

          describe ServiceBrokerApiAuthenticationFailed do
            let(:response_body) { 'foo' }
            let(:response) { double(code: 401, reason: 'Auth Error', body: response_body) }

            it 'initializes the base class correctly' do
              exception = ServiceBrokerApiAuthenticationFailed.new(uri, method, response)
              expect(exception.message).to eq("Authentication with the service broker failed. Double-check that the username and password are correct: #{uri}")
              expect(exception.uri).to eq(uri)
              expect(exception.method).to eq(method)
              expect(exception.source).to be(response.body)
            end

            it 'renders the correct status code to the user' do
              exception = ServiceBrokerApiAuthenticationFailed.new(uri, method, response)
              expect(exception.response_code).to eq 502
            end
          end
        end
      end
    end
  end
end
