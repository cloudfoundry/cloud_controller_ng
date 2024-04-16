require 'spec_helper'
require 'open_telemetry_middleware'
require 'securerandom'
require "opentelemetry/sdk"

module CloudFoundry
  module Middleware
    RSpec.describe OpenTelemetryFirstMiddleware do
      let(:middleware) { OpenTelemetryFirstMiddleware.new(app) }
      let(:app) { OpenTelemetryFirstMiddleware::FakeApp.new }
      # Was wird in die Propagators geschrieben?
      # Ließt B3 schreibt Jaeger
      # Alle werden Injected; Nur z.B. B3 extracted
      class OpenTelemetryFirstMiddleware::FakeApp
        attr_accessor :last_span, :last_trace
        def call(env)
          @last_span = OpenTelemetry::Trace.current_span.context.span_id
          @last_trace = OpenTelemetry::Trace.current_span.context.trace_id
          @header = env
          [200, {}, 'a body']
        end
      end

      describe 'handling the request tracecontext' do
        let(:trace_id) { SecureRandom.hex(16) }
        let(:span_id) { SecureRandom.hex(8) }
        let(:request_headers) do
          {
            'HTTP_TRACEPARENT' => "00-#{trace_id}-#{span_id}-01"
          }
        end

        context 'setting the trace headers in the logger' do
          it 'has assigned it before passing the request' do
            middleware.call(request_headers)
            expect(app.last_trace.unpack('H*').first).to eq(trace_id)
            expect(app.last_span.unpack('H*').first).to eq(span_id)
          end
        end

        context 'when the Jaeger headers are NOT passed in from outside' do
          it 'does not include trace_id and span_id' do
            middleware.call({})
            expect(app.last_trace.unpack('H*').first).to eq(null_trace_id)
            expect(app.last_span.unpack('H*').first).to eq(null_span_id)
          end
        end
      end

      describe "OpenTelemetryFirstMiddleware" do
        let(:trace_id) { SecureRandom.hex(16) }
        let(:span_id) { SecureRandom.hex(8) }
        let(:null_trace_id) { '00000000000000000000000000000000' }
        let(:null_span_id) { '0000000000000000' }

        #Tracecontext
        context 'setting the Tracecontext trace headers in the logger' do
          let(:used_request_headers) do
            {
              'HTTP_TRACEPARENT' => "00-#{trace_id}-#{span_id}-01"
            }
          end

          context "Tracecontext extractor and injector is configured" do
            before do
              TestConfig.override(
                otlp: {
                  tracing: {
                    enabled: true,
                    api_url: '', #https://127.0.0.1
                    api_token: '',
                    sampling_ratio: 1.0,
                    propagation: {
                      extractors: ['tracecontext'],
                      injectors: ['tracecontext']
                    }
                  }
                }
              )
            end

            it 'has assigned it before passing the request' do
              middleware.call(used_request_headers)
              expect(app.last_trace.unpack('H*').first).to eq(trace_id)
              expect(app.last_span.unpack('H*').first).to eq(span_id)
            end

          end

          context "Tracecontext extractor and injector is not configured" do
            before do
              TestConfig.override(
                otlp: {
                  tracing: {
                    enabled: true,
                    api_url: '',
                    api_token: '',
                    sampling_ratio: 1.0,
                    propagation: {
                      extractors: ['none'],
                      injectors: ['none']
                    }
                  }
                }
              )
            end


            it 'has no trace_id and span_id parsed from the request' do
              middleware.call(used_request_headers)
              expect(app.last_trace.unpack('H*').first).to eq(null_trace_id)
              expect(app.last_span.unpack('H*').first).to eq(null_span_id)
            end

          end

        end

        context 'when the Tracecontext headers are NOT passed in from outside' do
          let(:used_request_headers) { {} }

          context "Tracecontext extractor and injector is configured" do
            before do
              TestConfig.override(
                otlp: {
                  tracing: {
                    enabled: true,
                    api_url: '',
                    api_token: '',
                    sampling_ratio: 1.0,
                    propagation: {
                      extractors: ['tracecontext'],
                      injectors: ['tracecontext']
                    }
                  }
                }
              )
            end


            it 'has assigned it before passing the request' do
              middleware.call(used_request_headers)
              expect(app.last_trace.unpack('H*').first).to eq(null_trace_id)
              expect(app.last_span.unpack('H*').first).to eq(null_span_id)
            end
          end
        end


        #B3 Propagation
        context 'setting the B3 trace headers in the logger' do
          let(:used_request_headers) do
            {
              'HTTP_X_B3_TRACEID' => trace_id,
              'HTTP_X_B3_SPANID' => span_id
            }
          end

          context "b3 extractor and injector is configured" do
            before do
              TestConfig.override(
                otlp: {
                  tracing: {
                    enabled: true,
                    api_url: '', #https://127.0.0.1
                    api_token: '',
                    sampling_ratio: 1.0,
                    propagation: {
                      extractors: ['b3'],
                      injectors: ['b3']
                    }
                  }
                }
              )
            end

            it 'has assigned it before passing the request' do
              middleware.call(used_request_headers)
              expect(app.last_trace.unpack('H*').first).to eq(trace_id)
              expect(app.last_span.unpack('H*').first).to eq(span_id)
            end

          end

          context "b3 extractor and injector is not configured" do
            before do
              TestConfig.override(
                otlp: {
                  tracing: {
                    enabled: true,
                    api_url: '',
                    api_token: '',
                    sampling_ratio: 1.0,
                    propagation: {
                      extractors: ['none'],
                      injectors: ['none']
                    }
                  }
                }
              )
            end


            it 'has no trace_id and span_id parsed from the request' do
              middleware.call(used_request_headers)
              expect(app.last_trace.unpack('H*').first).to eq(null_trace_id)
              expect(app.last_span.unpack('H*').first).to eq(null_span_id)
            end

          end

        end

        context 'when the B3 headers are NOT passed in from outside' do
          let(:used_request_headers) { {} }

          context "B3 extractor and injector is configured" do
            before do
              TestConfig.override(
                otlp: {
                  tracing: {
                    enabled: true,
                    api_url: '',
                    api_token: '',
                    sampling_ratio: 1.0,
                    propagation: {
                      extractors: ['b3'],
                      injectors: ['b3']
                    }
                  }
                }
              )
            end


            it 'has assigned it before passing the request' do
              middleware.call(used_request_headers)
              expect(app.last_trace.unpack('H*').first).to eq(null_trace_id)
              expect(app.last_span.unpack('H*').first).to eq(null_span_id)
            end
          end
        end
      end

      describe 'handling the request b3multi' do
        TestConfig.override(
          otlp: {
            tracing: {
              enabled: true,
              api_url: '',
              api_token: '',
              sampling_ratio: 1.0,
              propagation: {
                extractors: ['b3multi'],
                injectors: ['b3multi']
              }
            }
          }
        )

        let(:trace_id) { SecureRandom.hex(16) }
        let(:span_id) { SecureRandom.hex(8) }
        let(:request_headers) do
          {
            'HTTP_B3' => "#{trace_id}-#{span_id}"
          }
        end

        context 'setting the trace headers in the logger' do
          it 'has assigned it before passing the request' do
            middleware.call(request_headers)
            expect(app.last_trace.unpack('H*').first).to eq(trace_id)
            expect(app.last_span.unpack('H*').first).to eq(span_id)
          end
        end

        context 'when the B3 single headers are NOT passed in from outside' do
          it 'does not include b3.trace_id and b3.span_id' do
            middleware.call({})
            expect(app.last_trace.unpack('H*').first).to eq(null_trace_id)
            expect(app.last_span.unpack('H*').first).to eq(null_span_id)
          end
        end
      end

      describe 'handling the request jaeger' do
        let(:trace_id) { SecureRandom.hex(16) }
        let(:span_id) { SecureRandom.hex(8) }
        let(:request_headers) do
          {
            'uber-trace-id' => "#{trace_id}:#{span_id}:0:1"
          }
        end

        context 'setting the trace headers in the logger' do
          it 'has assigned it before passing the request' do
            middleware.call(request_headers)
            expect(app.last_trace.unpack('H*').first).to eq(trace_id)
            expect(app.last_span.unpack('H*').first).to eq(span_id)
          end
        end

        context 'when the Jaeger headers are NOT passed in from outside' do
          it 'does not include trace_id and span_id' do
            middleware.call({})
            expect(app.last_trace.unpack('H*').first).to eq(null_trace_id)
            expect(app.last_span.unpack('H*').first).to eq(null_span_id)
          end
        end
      end

      describe 'handling the request xray' do
        let(:trace_id) { SecureRandom.hex(16) }
        let(:span_id) { SecureRandom.hex(8) }
        let(:request_headers) do
          {
            'X-Amzn-Trace-Id' => "Root=1-#{trace_id[0...8]}-#{trace_id[8...]};Parent=#{span_id};Sampled=1" #"Root=1-5759e988-bd862e3fe1be46a994272793;Parent=53995c3f42cd8ad8;Sampled=1"
          }
        end

        context 'setting the trace headers in the logger' do
          it 'has assigned it before passing the request' do
            middleware.call(request_headers)
            expect(app.last_trace.unpack('H*').first).to eq(trace_id)
            expect(app.last_span.unpack('H*').first).to eq(span_id)
          end
        end

        context 'when the Jaeger headers are NOT passed in from outside' do
          it 'does not include trace_id and span_id' do
            middleware.call({})
            expect(app.last_trace.unpack('H*').first).to eq(null_trace_id)
            expect(app.last_span.unpack('H*').first).to eq(null_span_id)
          end
        end
      end

      describe 'handling the request ottrace' do
        let(:trace_id) { SecureRandom.hex(16) }
        let(:span_id) { SecureRandom.hex(8) }
        let(:request_headers) do
          {
            'ot-tracer-traceid' => trace_id,
            'ot-tracer-spanid' => span_id
          }
        end

        context 'setting the trace headers in the logger' do
          it 'has assigned it before passing the request' do
            middleware.call(request_headers)
            expect(app.last_trace.unpack('H*').first).to eq(trace_id)
            expect(app.last_span.unpack('H*').first).to eq(span_id)
          end
        end

        context 'when the Jaeger headers are NOT passed in from outside' do
          it 'does not include trace_id and span_id' do
            middleware.call({})
            expect(app.last_trace.unpack('H*').first).to eq(null_trace_id)
            expect(app.last_span.unpack('H*').first).to eq(null_span_id)
          end
        end
      end

      describe 'handling the request b3 single and jaeger' do
        #First Header of Propagation method is used for propagation; Second one is being ignored
        let(:trace_id_1) { SecureRandom.hex(16) }
        let(:span_id_1) { SecureRandom.hex(8) }
        let(:trace_id_2) { SecureRandom.hex(16) }
        let(:span_id_2) { SecureRandom.hex(8) }
        let(:request_headers) do
          {
            'HTTP_X_B3_TRACEID' => trace_id_1,
            'HTTP_X_B3_SPANID' => span_id_1,
            'uber-trace-id' => "#{trace_id_2}:#{span_id_2}:0:1"
          }
        end

        context 'setting the trace headers in the logger' do
          it 'has assigned it before passing the request' do
            middleware.call(request_headers)
            expect(app.last_trace.unpack('H*').first).to eq(trace_id_1)
            expect(app.last_span.unpack('H*').first).to eq(span_id_1)
          end
        end

        context 'when the B3 single headers are NOT passed in from outside' do
          it 'does not include b3.trace_id and b3.span_id' do
            middleware.call({})
            expect(app.last_trace.unpack('H*').first).to eq(null_trace_id)
            expect(app.last_span.unpack('H*').first).to eq(null_span_id)
          end
        end
      end

      describe 'handling the request b3 and passing jaeger' do
        let(:trace_id) { SecureRandom.hex(16) }
        let(:span_id) { SecureRandom.hex(8) }
        let(:request_headers) do
          {
            'HTTP_X_B3_TRACEID' => trace_id,
            'HTTP_X_B3_SPANID' => span_id
          }
        end

        context 'setting the b3 trace headers in the logger' do
          it 'has assigned jaeger headers before passing the request' do
            middleware.call(request_headers)
            #todo wie komme ich an die header?
          end
        end
      end
    end
  end
end
