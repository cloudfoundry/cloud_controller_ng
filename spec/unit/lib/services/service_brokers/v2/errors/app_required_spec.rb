require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        RSpec.describe 'AppRequired' do
          let(:response_body) { '{"error": "RequiresApp", "description": "error message"}' }
          let(:response) { instance_double(HttpResponse, code: 422, message: 'Unprocessable Entity', body: response_body) }

          let(:uri) { 'http://uri.example.com' }
          let(:method) { 'POST' }
          let(:error) { StandardError.new }

          it 'initializes the base class correctly' do
            exception = AppRequired.new(uri, method, response)
            expect(exception.message).to eq('This service supports generation of credentials through binding an application only.')
            expect(exception.uri).to eq(uri)
            expect(exception.method).to eq(method)
            expect(exception.source).to eq(MultiJson.load(response.body))
          end

          it 'has a response_code of 400' do
            exception = AppRequired.new(uri, method, response)
            expect(exception.response_code).to eq(400)
          end
        end
      end
    end
  end
end
