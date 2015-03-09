require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        describe ServiceBrokerBadResponse do
          let(:uri) { 'http://www.example.com/' }
          let(:response) { double(code: 500, message: 'Internal Server Error', body: response_body) }
          let(:method) { 'PUT' }

          context 'with a description in the body' do
            let(:response_body) do
              {
                'description' => 'Some error text'
              }.to_json
            end

            it 'generates the correct hash' do
              exception = described_class.new(uri, method, response)
              exception.set_backtrace(['/foo:1', '/bar:2'])

              expect(exception.to_h).to eq({
                'description' => 'Service broker error: Some error text',
                'backtrace' => ['/foo:1', '/bar:2'],
                'http' => {
                  'status' => 500,
                  'uri' => uri,
                  'method' => 'PUT'
                },
                'source' => {
                  'description' => 'Some error text'
                }
              })
            end

            it 'renders the correct status code to the user' do
              exception = described_class.new(uri, method, response)
              expect(exception.response_code).to eq 502
            end
          end

          context 'without a description in the body' do
            let(:response_body) do
              { 'foo' => 'bar' }.to_json
            end

            it 'generates the correct hash' do
              exception = described_class.new(uri, method, response)
              exception.set_backtrace(['/foo:1', '/bar:2'])

              expect(exception.to_h).to eq({
                'description' => 'The service broker returned an invalid response for the request to http://www.example.com/. ' \
                                 "Status Code: 500 Internal Server Error, Body: #{response_body}",
                'backtrace' => ['/foo:1', '/bar:2'],
                'http' => {
                  'status' => 500,
                  'uri' => uri,
                  'method' => 'PUT'
                },
                'source' => { 'foo' => 'bar' }
              })
            end

            it 'renders the correct status code to the user' do
              exception = described_class.new(uri, method, response)
              expect(exception.response_code).to eq 502
            end
          end
        end
      end
    end
  end
end
