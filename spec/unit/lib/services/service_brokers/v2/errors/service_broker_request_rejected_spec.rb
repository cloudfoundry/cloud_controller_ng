require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        describe ServiceBrokerRequestRejected do
          let(:uri) { 'http://www.example.com/' }
          let(:response) { double(code: 400, message: 'Generic bad request error', body: response_body) }
          let(:method) { 'PUT' }

          context 'with a description in the body' do
            context 'and an error code' do
              let(:response_body) do
                {
                  'description' => 'Some error text',
                  'error' => 'AsyncRequired',
                }.to_json
              end

              it 'returns the description set up by the error key' do
                exception = described_class.new(uri, method, response)
                exception.set_backtrace(['/foo:1', '/bar:2'])

                details = VCAP::Errors::Details.new('AsyncRequired')
                expect(exception.to_h).to eq({
                  'description' => details.message_format,
                  'backtrace' => ['/foo:1', '/bar:2'],
                  'http' => {
                    'status' => details.response_code,
                    'uri' => uri,
                    'method' => 'PUT'
                  },
                  'source' => {
                    'description' => 'Some error text',
                    'error' => 'AsyncRequired',
                  }
                })
              end

              it 'renders the correct status code to the user' do
                exception = described_class.new(uri, method, response)
                expect(exception.response_code).to eq 502
              end
            end

            context 'and no error code' do
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
                    'status' => 400,
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
          end

          context 'without a description in the body' do
            context 'and an error code' do
              let(:response_body) do
                {
                  'error' => 'AsyncRequired',
                }.to_json
              end

              it 'returns the description set up by the error key' do
                exception = described_class.new(uri, method, response)
                exception.set_backtrace(['/foo:1', '/bar:2'])

                details = VCAP::Errors::Details.new('AsyncRequired')
                expect(exception.to_h).to eq({
                  'description' => details.message_format,
                  'backtrace' => ['/foo:1', '/bar:2'],
                  'http' => {
                    'status' => details.response_code,
                    'uri' => uri,
                    'method' => 'PUT'
                  },
                  'source' => {
                    'error' => 'AsyncRequired',
                  }
                })
              end

              it 'renders the correct status code to the user' do
                exception = described_class.new(uri, method, response)
                expect(exception.response_code).to eq 502
              end
            end

            context 'and no error code' do
              let(:response_body) do
                { 'foo' => 'bar' }.to_json
              end

              it 'generates the correct hash' do
                exception = described_class.new(uri, method, response)
                exception.set_backtrace(['/foo:1', '/bar:2'])

                expect(exception.to_h).to eq({
                  'description' => VCAP::Errors::ApiError.new_from_details('ServiceBrokerRequestRejected', 'http://www.example.com/', 400, 'Generic bad request error').message,
                  'backtrace' => ['/foo:1', '/bar:2'],
                  'http' => {
                    'status' => 400,
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

          context 'with invalid JSON body' do
            let(:response_body) { 'garbage' }

            it 'return an error as if there was no description or error keys' do
              exception = described_class.new(uri, method, response)
              exception.set_backtrace(['/foo:1', '/bar:2'])

              expect(exception.to_h).to eq({
                'description' => VCAP::Errors::ApiError.new_from_details('ServiceBrokerRequestRejected', 'http://www.example.com/', 400, 'Generic bad request error').message,
                'backtrace' => ['/foo:1', '/bar:2'],
                'http' => {
                  'status' => 400,
                  'uri' => uri,
                  'method' => 'PUT'
                },
                'source' => 'garbage'
              })
            end
          end
        end
      end
    end
  end
end
