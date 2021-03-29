require 'spec_helper'
require 'zipkin'
require 'securerandom'

module CloudFoundry
  module Middleware
    RSpec.describe Zipkin do
      let(:middleware) { Zipkin.new(app) }
      let(:app) { FakeApp.new }

      class FakeApp
        attr_accessor :last_trace_id, :last_span_id, :last_env_input

        def call(env)
          @last_trace_id = ::VCAP::Request.b3_trace_id
          @last_span_id = ::VCAP::Request.b3_span_id
          @last_env_input = env
          [200, {}, 'a body']
        end
      end

      describe 'handling the request' do
        let(:trace_id) { SecureRandom.hex(8) }
        let(:span_id) { SecureRandom.hex(8) }
        let(:request_headers) do
          {
            'HTTP_X_B3_TRACEID' => trace_id,
            'HTTP_X_B3_SPANID'  => span_id
          }
        end

        context 'setting the trace headers in the logger' do
          it 'has assigned it before passing the request' do
            middleware.call(request_headers)
            expect(app.last_trace_id).to eq trace_id
            expect(app.last_span_id).to eq span_id
          end

          it 'nils it out after the request has been processed' do
            middleware.call(request_headers)
            expect(::VCAP::Request.b3_trace_id).to eq(nil)
            expect(::VCAP::Request.b3_span_id).to eq(nil)
          end
        end

        context 'when the Zipkin (B3) headers are passed in from outside' do
          it 'includes it in b3.trace_id and b3.span_id' do
            middleware.call(request_headers)
            expect(app.last_env_input['b3.trace_id']).to eq trace_id
            expect(app.last_env_input['b3.span_id']).to eq span_id
          end
        end

        context 'when the Zipkin (B3) headers are NOT passed in from outside' do
          it 'does not include b3.trace_id and b3.span_id' do
            middleware.call({})
            expect(app.last_env_input['b3.trace_id']).to be_nil
            expect(app.last_env_input['b3.span_id']).to be_nil
          end
        end
      end

      describe 'the response' do
        let(:trace_id) { SecureRandom.hex(8) }
        let(:span_id) { SecureRandom.hex(8) }

        context 'when the Zipkin (B3) headers are passed in' do
          let(:request_headers) do
            {
              'HTTP_X_B3_TRACEID' => trace_id,
              'HTTP_X_B3_SPANID'  => span_id
            }
          end

          it 'is returned in the response' do
            _, headers, _ = middleware.call(request_headers)

            expect(headers['X-B3-TraceId']).to eq trace_id
            expect(headers['X-B3-SpanId']).to eq span_id
          end
        end

        context 'when the Zipkin (B3) headers are NOT passed in' do
          it 'does not return any Zipkin (B3) headers' do
            _, headers, _ = middleware.call({})

            expect(headers['X-B3-TraceId']).to be_nil
            expect(headers['X-B3-SpanId']).to be_nil
          end
        end
      end
    end
  end
end
