require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        RSpec.describe ServiceBrokerRequestRejected do
          let(:uri) { 'http://www.example.com/' }
          let(:response) { double(code: 400, message: 'status message', body: response_body) }
          let(:method) { 'PUT' }

          context 'with a description in the body' do
            let(:response_body) do
              {
                'description' => 'Some error text'
              }.to_json
            end

            it 'generates the correct hash' do
              exception = ServiceBrokerRequestRejected.new(uri, method, response)
              exception.set_backtrace(['/foo:1', '/bar:2'])

              expect(exception.to_h).to eq({
                'description' => 'Service broker error: Some error text',
                'backtrace' => ['/foo:1', '/bar:2'],
                'http' => {
                  'status' => 400,
                  'method' => 'PUT'
                },
                'source' => {
                  'description' => 'Some error text'
                }
              })
            end

            it 'renders the correct status code to the user' do
              exception = ServiceBrokerRequestRejected.new(uri, method, response)
              expect(exception.response_code).to eq 502
            end
          end

          context 'without a description in the body' do
            let(:response_body) do
              { 'foo' => 'bar' }.to_json
            end

            it 'generates the correct hash' do
              exception = ServiceBrokerRequestRejected.new(uri, method, response)
              exception.set_backtrace(['/foo:1', '/bar:2'])

              expect(exception.to_h).to eq({
                'description' => "The service broker rejected the request. Status Code: 400 status message, Body: #{response_body}",
                'backtrace' => ['/foo:1', '/bar:2'],
                'http' => {
                  'status' => 400,
                  'method' => 'PUT'
                },
                'source' => { 'foo' => 'bar' }
              })
            end

            it 'renders the correct status code to the user' do
              exception = ServiceBrokerRequestRejected.new(uri, method, response)
              expect(exception.response_code).to eq 502
            end
          end
        end
      end
    end
  end
end
