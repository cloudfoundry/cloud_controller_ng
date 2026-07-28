require 'lightweight_spec_helper'
require 'cloud_controller/structured_error'
require 'cloud_controller/http_request_error'
require 'services/service_brokers/v2/errors/service_broker_api_timeout'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        RSpec.describe ServiceBrokerApiTimeout do
          let(:uri) { 'http://uri.example.com' }
          let(:method) { 'POST' }
          let(:error) { StandardError.new }

          it 'initializes the base class correctly' do
            exception = ServiceBrokerApiTimeout.new(uri, method, error)
            expect(exception.message).to eq('The request to the service broker timed out')
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
