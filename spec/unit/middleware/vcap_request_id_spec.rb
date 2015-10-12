require 'spec_helper'
require 'vcap_request_id'

module CloudFoundry
  module Middleware
    describe VcapRequestId do
      let(:middleware) { described_class.new(app) }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:uuid_regex) { '\w+-\w+-\w+-\w+-\w+' }

      describe 'handling the request' do
        context 'when HTTP_X_VCAP_REQUEST_ID is passed in from outside' do
          it 'includes it in cf.request_id and appends a uuid to ensure uniqueness' do
            middleware.call('HTTP_X_VCAP_REQUEST_ID' => 'request-id')

            expect(app).to have_received(:call) do |env|
              expect(env['cf.request_id']).to match(/^request-id::#{uuid_regex}$/)
            end
          end

          it 'accepts only alphanumeric request ids' do
            middleware.call('HTTP_X_VCAP_REQUEST_ID' => '; X-Hacked-Header: Stuff')

            expect(app).to have_received(:call) do |env|
              expect(env['cf.request_id']).to match(/^X-Hacked-HeaderStuff::#{uuid_regex}$/)
            end
          end

          it 'accepts only 255 characters in the passed-in request id' do
            middleware.call('HTTP_X_VCAP_REQUEST_ID' => 'x' * 500)

            truncated_passed_id = 'x' * 255
            expect(app).to have_received(:call) do |env|
              expect(env['cf.request_id']).to match(/^#{truncated_passed_id}::#{uuid_regex}$/)
            end
          end

          context 'when HTTP_X_REQUEST_ID is also passed in from outside' do
            it 'preferes HTTP_X_VCAP_REQUEST_ID' do
              middleware.call('HTTP_X_VCAP_REQUEST_ID' => 'request-id', 'HTTP_X_REQUEST_ID' => 'not-vcap-request-id')

              expect(app).to have_received(:call) do |env|
                expect(env['cf.request_id']).to match(/^request-id::#{uuid_regex}$/)
              end
            end
          end
        end

        context 'when HTTP_X_VCAP_REQUEST_ID is NOT passed in from outside' do
          it 'generates a uuid as the request_id' do
            middleware.call({})

            expect(app).to have_received(:call) do |env|
              expect(env['cf.request_id']).to match(/^#{uuid_regex}$/)
            end
          end

          context 'when HTTP_X_REQUEST_ID is passed in from outside' do
            it 'includes it in cf.request_id and appends a uuid to ensure uniqueness' do
              middleware.call('HTTP_X_REQUEST_ID' => 'not-vcap-request-id')

              expect(app).to have_received(:call) do |env|
                expect(env['cf.request_id']).to match(/^not-vcap-request-id::#{uuid_regex}$/)
              end
            end
          end
        end
      end

      describe 'the response' do
        context 'when the request id is passed in' do
          it 'is returned in the response' do
            _, response_headers, _ = middleware.call('HTTP_X_VCAP_REQUEST_ID' => 'request-id')

            expect(response_headers['X-VCAP-Request-ID']).to match(/^request-id::#{uuid_regex}$/)
          end
        end

        context 'when the request id is NOT passed in' do
          it 'returns a generated id in the response' do
            _, response_headers, _ = middleware.call({})

            expect(response_headers['X-VCAP-Request-ID']).to match(/^#{uuid_regex}$/)
          end
        end
      end
    end
  end
end
