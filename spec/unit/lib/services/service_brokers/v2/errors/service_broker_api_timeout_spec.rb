require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        describe ServiceBrokerApiTimeout do
          let(:uri) { 'http://uri.example.com' }
          let(:method) { 'POST' }
          let(:error) { StandardError.new }

          it 'initializes the base class correctly' do
            exception = ServiceBrokerApiTimeout.new(uri, method, error)
            expect(exception.message).to eq("The request to the service broker timed out: #{uri}")
            expect(exception.uri).to eq(uri)
            expect(exception.method).to eq(method)
            expect(exception.source).to be(error)
          end

          it 'renders the correct status code to the user' do
            exception = ServiceBrokerApiTimeout.new(uri, method, error)
            expect(exception.response_code).to eq 504
          end
        end
      end
    end
  end
end
