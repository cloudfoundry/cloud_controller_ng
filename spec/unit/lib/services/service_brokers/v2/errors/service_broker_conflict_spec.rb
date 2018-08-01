require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        RSpec.describe 'ServiceBrokerConflict' do
          let(:error_message) { 'error message' }
          let(:response_body) { "{\"description\": \"#{error_message}\"}" }
          let(:response) { double(code: 409, reason: 'Conflict', body: response_body) }

          let(:uri) { 'http://uri.example.com' }
          let(:method) { 'POST' }
          let(:error) { StandardError.new }

          it 'initializes the base class correctly' do
            exception = ServiceBrokerConflict.new(uri, method, response)
            expect(exception.message).to eq("Service broker error: #{error_message}")
            expect(exception.uri).to eq(uri)
            expect(exception.method).to eq(method)
            expect(exception.source).to eq(MultiJson.load(response.body))
          end

          it 'has a response_code of 409' do
            exception = ServiceBrokerConflict.new(uri, method, response)
            expect(exception.response_code).to eq(409)
          end

          context 'when the response body has no description field' do
            let(:response_body) { '{"field": "value"}' }

            it 'initializes the base class correctly' do
              exception = ServiceBrokerConflict.new(uri, method, response)
              expect(exception.message).to eq("Resource conflict: #{uri}")
              expect(exception.uri).to eq(uri)
              expect(exception.method).to eq(method)
              expect(exception.source).to eq(MultiJson.load(response.body))
            end
          end

          context 'when the body is not JSON-parsable' do
            let(:response_body) { 'foo' }

            it 'initializes the base class correctly' do
              exception = ServiceBrokerConflict.new(uri, method, response)
              expect(exception.message).to eq("Resource conflict: #{uri}")
              expect(exception.uri).to eq(uri)
              expect(exception.method).to eq(method)
              expect(exception.source).to eq(response.body)
            end
          end
        end
      end
    end
  end
end
