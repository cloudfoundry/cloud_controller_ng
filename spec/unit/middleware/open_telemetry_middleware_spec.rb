require 'spec_helper'
require 'open_telemetry_middleware'
require 'securerandom'
require "opentelemetry/sdk"

module CloudFoundry
  module Middleware
    RSpec.describe OpenTelemetryFirstMiddleware, OpenTelemetryLastMiddleware do
      # Register Middlewares and App for Testing
      let(:fake_app) { FakeApp.new }
      let(:middlewares) { OpenTelemetryFirstMiddleware.new(OpenTelemetryLastMiddleware.new(fake_app))}

      # Generate IDs for Testing
      let(:trace_id) { SecureRandom.hex(16) }
      let(:span_id) { SecureRandom.hex(8) }
      let(:parent_span_id) { SecureRandom.hex(8) }

      class FakeApp
        attr_reader :last_trace, :last_span_id, :last_parent_span_id, :last_trace_id, :last_baggage_values, :last_span_sampled, :parsed_span_id, :parsed_parent_span_id, :parsed_trace_id, :parsed_baggage_values, :parsed_span_sampled
        def call(env)
          # Record trace and baggage values to test extraction
          @last_span_id = OpenTelemetry::Trace.current_span.context.span_id.unpack('H*').first
          @last_parent_span_id = OpenTelemetry::Trace.current_span.respond_to?(:parent_span_id) ? OpenTelemetry::Trace.current_span.parent_span_id.unpack('H*').first : nil
          @last_trace_id = OpenTelemetry::Trace.current_span.context.trace_id.unpack('H*').first
          @last_baggage_values = OpenTelemetry::Baggage.values
          @last_span_sampled = OpenTelemetry::Trace.current_span.context.trace_flags.sampled?
          OpenTelemetry::Context.with_current(OpenTelemetry.propagation.extract(env, getter: OpenTelemetry::Common::Propagation.rack_env_getter)) do
            @parsed_span_id = OpenTelemetry::Trace.current_span.context.span_id.unpack('H*').first
            @parsed_parent_span_id = OpenTelemetry::Trace.current_span.respond_to?(:parent_span_id) ? OpenTelemetry::Trace.current_span.parent_span_id.unpack('H*').first : nil
            @parsed_trace_id = OpenTelemetry::Trace.current_span.context.trace_id.unpack('H*').first
            @parsed_baggage_values = OpenTelemetry::Baggage.values
            @parsed_span_sampled = OpenTelemetry::Trace.current_span.context.trace_flags.sampled?
          end
          # Make outgoing http calls to test injection
          OpenTelemetry::Context.with_current(OpenTelemetry::Baggage.set_value('test', 'bommel')) do
            # Make a http call with Net::HTTP
            http = Net::HTTP.new("fake.net_http.request")
            request                  = Net::HTTP::Get.new("/", {})
            request.body             = "a request body"
            http.start.request(request)
            # Make a http call with Net::HTTP over alternative ways
            Net::HTTP.get(URI("http://fake.net_http.request/"))
            # Make a http call with HTTPClient
            HTTPClient.new.request(:get, "http://fake.http_client.request/", body: nil, header:{})
          end
          [200, {}, 'a capi response body']
        end
      end

      before do
        WebMock::API::stub_request(:get, 'http://fake.net_http.request/')
        WebMock::API::stub_request(:get, 'http://fake.http_client.request/')
      end

      def configure_otlp(extractors, injectors, sampling_ratio: 1.0, accept_sampling_instruction: false, redact_db_statement: true)
        TestConfig.override(
          otlp: {
            tracing: {
              enabled: true,
              api_url: 'http://fake.request',
              api_token: '123',
              sampling_ratio: sampling_ratio,
              redact: {
                db_statement: redact_db_statement
              },
              propagation: {
                accept_sampling_instruction: accept_sampling_instruction,
                extractors: extractors,
                injectors: injectors
              }
            }
          }
        )
      end

      describe 'sampler' do
        context 'when accept_sampling_instruction is set to true' do
          it 'does use the ParentBased sampler' do
            configure_otlp([], [], sampling_ratio: 0, accept_sampling_instruction: true)
            middlewares.call({})
            expect(OpenTelemetry::tracer_provider.sampler).to be_an_instance_of(OpenTelemetry::SDK::Trace::Samplers::ParentBased)
          end
          context 'when sampling_ratio is set to 0' do
            it 'does not sample the request' do
              configure_otlp([], [], sampling_ratio: 0, accept_sampling_instruction: true)
              middlewares.call({})
              expect(fake_app.last_span_sampled).to eq(false)
            end
          end
          context 'when sampling_ratio is set to 1' do
            it 'samples the request' do
              configure_otlp([], [], sampling_ratio: 1, accept_sampling_instruction: true)
              middlewares.call({})
              expect(fake_app.last_span_sampled).to eq(true)
            end
          end
          context 'when sampling_ratio is set to 0.5' do
            it 'samples the request' do
              configure_otlp([], [], sampling_ratio: 0.5, accept_sampling_instruction: true)
              sampled_requests = 0
              1000.times do
                middlewares.call({})
                sampled_requests += 1 if fake_app.last_span_sampled
              end
              expect(sampled_requests).to be_within(50).of(500)
            end
          end
          context 'when sampling_ratio is out of bounds' do
            it 'throws an exception on loading the configuration' do
              expect{configure_otlp([], [], sampling_ratio: 1.1, accept_sampling_instruction: true)}.to raise_error(ArgumentError)
              expect{configure_otlp([], [], sampling_ratio: -0.1, accept_sampling_instruction: true)}.to raise_error(ArgumentError)
            end
          end
        end
        context 'when accept_sampling_instruction is set to false' do
          it 'does use the TraceIdRatioBased sampler' do
            configure_otlp([], [], sampling_ratio: 0, accept_sampling_instruction: false)
            middlewares.call({})
            expect(OpenTelemetry::tracer_provider.sampler).to be_an_instance_of(OpenTelemetry::SDK::Trace::Samplers::TraceIdRatioBased)
          end
          context 'when sampling_ratio is set to 0' do
            it 'does not sample the request' do
              configure_otlp([], [], sampling_ratio: 0, accept_sampling_instruction: false)
              middlewares.call({})
              expect(fake_app.last_span_sampled).to eq(false)
            end
          end
          context 'when sampling_ratio is set to 1' do
            it 'samples the request' do
              configure_otlp([], [], sampling_ratio: 1, accept_sampling_instruction: false)
              middlewares.call({})
              expect(fake_app.last_span_sampled).to eq(true)
            end
          end
          context 'when sampling_ratio is set to 0.5' do
            it 'samples the request' do
              configure_otlp([], [], sampling_ratio: 0.5, accept_sampling_instruction: false)
              sampled_requests = 0
              1000.times do
                middlewares.call({})
                sampled_requests += 1 if fake_app.last_span_sampled
              end
              expect(sampled_requests).to be_within(50).of(500)
            end
          end
          context 'when sampling_ratio is out of bounds' do
            it 'throws an exception on loading the configuration' do
              expect{configure_otlp([], [], sampling_ratio: 1.1, accept_sampling_instruction: false)}.to raise_error(ArgumentError)
              expect{configure_otlp([], [], sampling_ratio: -0.1, accept_sampling_instruction: false)}.to raise_error(ArgumentError)
            end
          end
        end
      end

      describe 'middleware performance' do
        it 'does not have a significant performance impact' do
          configure_otlp([], [], sampling_ratio: 1)
          expect{middlewares.call({})}.to perform_under(2).ms.warmup(2).times.sample(10).times
        end
      end

      describe 'root span request related attributes' do
        let(:tracer) { instance_double('OpenTelemetry::SDK::Trace::Tracer') }
        before do
          configure_otlp([], [], sampling_ratio: 1)
          allow(OpenTelemetry.tracer_provider).to receive(:tracer).and_return(tracer)
          allow(tracer).to receive(:in_span)
        end
        context 'when the request contains the following headers' do
          let(:rack_env) {
            {"SERVER_SOFTWARE"=>"thin 1.8.2 codename Ruby Razor", "SERVER_NAME"=>"localhost", "rack.version"=>[1, 0], "rack.multithread"=>true, "rack.multiprocess"=>false, "rack.run_once"=>false, "REQUEST_METHOD"=>"POST", "REQUEST_PATH"=>"/v3/security_groups", "PATH_INFO"=>"/v3/security_groups", "REQUEST_URI"=>"/v3/security_groups?name=test", "HTTP_VERSION"=>"HTTP/1.0", "HTTP_HOST"=>"localhost", "HTTP_X_REAL_IP"=>"192.168.1.2", "HTTP_X_FORWARDED_FOR"=>"192.168.1.2", "HTTP_CONNECTION"=>"close", "HTTP_USER_AGENT"=>"cf/8.7.1+9c81242.2023-06-15 (go1.20.5; arm64 darwin)", "HTTP_ACCEPT"=>"application/json", "HTTP_ACCEPT_ENCODING"=>"gzip", "CONTENT_LENGTH"=>"321", "CONTENT_TYPE"=>"application/json", "GATEWAY_INTERFACE"=>"CGI/1.2", "SERVER_PORT"=>"80", "QUERY_STRING"=>"name=test", "SERVER_PROTOCOL"=>"HTTP/1.1", "rack.url_scheme"=>"http", "SCRIPT_NAME"=>"", "REMOTE_ADDR"=>"127.0.0.1"}
          }
          let(:wanted_attributes) {
            {
              'http.request.method' => 'POST',
              'url.path' => '/v3/security_groups',
              'url.scheme' => 'http',
              'url.query'=> 'name=test',
              'url.full' => '/v3/security_groups?name=test',
              'http.host' => 'localhost',
              'user_agent.original' => 'cf/8.7.1+9c81242.2023-06-15 (go1.20.5; arm64 darwin)',
              'http.request.header.connection' => 'close',
              'http.request.header.version' => 'HTTP/1.0',
              'http.request.header.x_real_ip' => '192.168.1.2',
              'http.request.header.x_forwared_for' => '192.168.1.2',
              'http.request.header.accept' => 'application/json',
              'http.request.header.accept_encoding' => 'gzip',
              'http.request.body.size' => '321',
            }
          }
          it 'does set the correct attributes' do
            middlewares.call(rack_env)
            expect(tracer).to have_received(:in_span).exactly(1).times.with('/v3/security_groups', attributes: wanted_attributes, kind: :server)
          end
        end

        context 'when the request has no headers' do
          let(:wanted_attributes) {
            {
              'http.request.method' => '',
              'url.path' => '',
              'url.scheme' =>  '',
              'url.query'=> '',
              'url.full' => '',
              'http.host' => '',
              'user_agent.original' => '',
              'http.request.header.connection' => '',
              'http.request.header.version' => '',
              'http.request.header.x_real_ip' => '',
              'http.request.header.x_forwared_for' => '',
              'http.request.header.accept' => '',
              'http.request.header.accept_encoding' => '',
              'http.request.body.size' => '',
            }
          }
          it 'does set empty strings as attributes' do
            middlewares.call({})
            expect(tracer).to have_received(:in_span).exactly(1).times.with('unknown', attributes: wanted_attributes, kind: :server)
          end
        end
      end

      describe "root span response related attributes" do
        it 'does record the status code and response body size' do
          span = instance_double('Span')
          allow_any_instance_of(OpenTelemetry::Trace::Tracer).to receive(:in_span).and_yield(span)

          expect(span).to receive(:set_attribute).with('http.response.status_code', 200)
          expect(span).to receive(:set_attribute).with('http.response.body.size', 20)

          middlewares.call({})
        end
      end

      describe 'tracing secret/information redaction' do
        let(:configurator) {double.as_null_object}
        let(:tracer_provider) { double('TracerProvider', sampler: nil) }

        before do
          allow(OpenTelemetry::SDK).to receive(:configure).and_yield(configurator)
          allow(tracer_provider).to receive(:sampler=)
          allow(OpenTelemetry).to receive(:tracer_provider).and_return(tracer_provider)
        end

        context 'when redaction is not configured' do
          it 'does propagate the :include redaction decision to the instrumentation' do
            if defined?(::PG) # If postgres gem is loaded
              expect(configurator).to receive(:use).with('OpenTelemetry::Instrumentation::PG', { db_statement: :include })
            else # If mysql2 gem is loaded
              expect(configurator).to receive(:use).with('OpenTelemetry::Instrumentation::Mysql2', { db_statement: :include })
            end
            configure_otlp([], [], redact_db_statement: false)
          end
        end

        context 'when redaction is configured' do
          it 'does propagate the :obfuscate redaction decision to the instrumentation' do
            if defined?(::PG) # If postgres gem is loaded
              expect(configurator).to receive(:use).with('OpenTelemetry::Instrumentation::PG', { db_statement: :obfuscate })
            else # If mysql2 gem is loaded
              expect(configurator).to receive(:use).with('OpenTelemetry::Instrumentation::Mysql2', { db_statement: :obfuscate })
            end
            configure_otlp([], [])
          end
        end
      end

      describe 'extractors behaviour in regards to received request headers' do

        describe "b3multi" do
          before do
            configure_otlp(['b3multi'], [])
          end

          it 'does parse the b3multi headers' do
            middlewares.call(
              {
                'HTTP_X_B3_TRACEID' => trace_id,
                'HTTP_X_B3_SPANID' => span_id,
                'HTTP_X_B3_SAMPLED' => '1',
                'HTTP_X_B3_PARENTSPANID' => parent_span_id
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.parsed_parent_span_id).to be_nil
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'does not requre optional fields' do
            middlewares.call(
              {
                'HTTP_X_B3_TRACEID' => trace_id,
                'HTTP_X_B3_SPANID' => span_id,
                'HTTP_X_B3_SAMPLED' => '0'
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'does not parse the b3multi headers when no b3multi extractor is configured' do
            configure_otlp([], [])
            middlewares.call(
              {
                'HTTP_X_B3_TRACEID' => trace_id,
                'HTTP_X_B3_SPANID' => span_id,
                'HTTP_X_B3_SAMPLED' => '1',
                'HTTP_X_B3_PARENTSPANID' => parent_span_id
              }
            )
            expect(fake_app.parsed_trace_id).to eq(fake_app.last_trace_id)
            expect(fake_app.parsed_span_id).to eq(fake_app.last_span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'processes the b3single header despite b3multi is configured' do
            middlewares.call(
              {
                'HTTP_B3' => "#{trace_id}-#{span_id}-1-#{parent_span_id}"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'processes the b3single header without optional fields despite b3multi is configured' do
            middlewares.call(
              {
                'HTTP_B3' => "#{trace_id}-#{span_id}"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          describe 'the behaviour when the sampling header is set' do
            context 'when accept_sampling_instruction is false' do
              it 'does not enforce sampling when the sampling header is set to 1' do
                configure_otlp(['b3multi'], [], sampling_ratio: 0)
                middlewares.call(
                  {
                    'HTTP_X_B3_TRACEID' => trace_id,
                    'HTTP_X_B3_SPANID' => span_id,
                    'HTTP_X_B3_SAMPLED' => '1'
                  }
                )
                expect(fake_app.last_span_sampled).to eq(false)
              end

              it 'does not skip sampling when the sampling header is set to 0' do
                middlewares.call(
                  {
                    'HTTP_X_B3_TRACEID' => trace_id,
                    'HTTP_X_B3_SPANID' => span_id,
                    'HTTP_X_B3_SAMPLED' => '0'
                  }
                )
                expect(fake_app.last_span_sampled).to eq(true)
              end
            end
            context 'when accept_sampling_instruction is true' do
              it 'does force sampling when the sampling header is set to 1' do
                configure_otlp(['b3multi'], [], sampling_ratio: 0, accept_sampling_instruction: true)
                middlewares.call(
                  {
                    'HTTP_X_B3_TRACEID' => trace_id,
                    'HTTP_X_B3_SPANID' => span_id,
                    'HTTP_X_B3_SAMPLED' => '1'
                  }
                )
                expect(fake_app.last_span_sampled).to eq(true)
              end
              it 'does prevent sampling when the sampling header is set to 0' do
                configure_otlp(['b3multi'], [], sampling_ratio: 1, accept_sampling_instruction: true)
                middlewares.call(
                  {
                    'HTTP_X_B3_TRACEID' => trace_id,
                    'HTTP_X_B3_SPANID' => span_id,
                    'HTTP_X_B3_SAMPLED' => '0'
                  }
                )
                expect(fake_app.last_span_sampled).to eq(false)
              end
            end
          end
        end

        describe "b3" do
          before do
            configure_otlp(['b3'], [], sampling_ratio: 1.0)
          end

          it 'processes the b3 header when the b3 extractor is configured' do
            middlewares.call(
              {
                'HTTP_B3' => "#{trace_id}-#{span_id}-1-#{parent_span_id}"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'processes the b3 header without optional fields when the b3 extractor is configured' do
            middlewares.call(
              {
                'HTTP_B3' => "#{trace_id}-#{span_id}"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'does not parse the b3 header when no b3 extractor is configured' do
            configure_otlp([], [])
            middlewares.call(
              {
                'HTTP_B3' => "#{trace_id}-#{span_id}-1-#{parent_span_id}"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(fake_app.last_trace_id)
            expect(fake_app.parsed_span_id).to eq(fake_app.last_span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'does parse the b3multi headers despite b3 being configured' do
            middlewares.call(
              {
                'HTTP_X_B3_TRACEID' => trace_id,
                'HTTP_X_B3_SPANID' => span_id,
                'HTTP_X_B3_SAMPLED' => '1',
                'HTTP_X_B3_PARENTSPANID' => parent_span_id
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'does parse the b3multi headers despite b3 being configured without optional fields' do
            middlewares.call(
              {
                'HTTP_X_B3_TRACEID' => trace_id,
                'HTTP_X_B3_SPANID' => span_id
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          describe 'the behaviour when the sampling header is set' do
            context 'when accept_sampling_instruction is false' do
              it 'does not enforce sampling when the sampling header is set to 1' do
                configure_otlp(['b3'], [], sampling_ratio: 0)
                middlewares.call(
                  { 'HTTP_B3' => "#{trace_id}-#{span_id}-1" }
                )
                expect(fake_app.last_span_sampled).to eq(false)
              end

              it 'does not skip sampling when the sampling header is set to 0' do
                middlewares.call(
                  { 'HTTP_B3' => "#{trace_id}-#{span_id}-0" }
                )
                expect(fake_app.last_span_sampled).to eq(true)
              end
            end

            context 'when accept_sampling_instruction is true' do
              it 'does force sampling when the sampling header is set to 1' do
                configure_otlp(['b3'], [], sampling_ratio: 0, accept_sampling_instruction: true)
                middlewares.call(
                  { 'HTTP_B3' => "#{trace_id}-#{span_id}-1" }
                )
                expect(fake_app.last_span_sampled).to eq(true)
              end
              it 'does prevent sampling when the sampling header is set to 0' do
                configure_otlp(['b3'], [], sampling_ratio: 1, accept_sampling_instruction: true)
                middlewares.call(
                  { 'HTTP_B3' => "#{trace_id}-#{span_id}-0" }
                )
                expect(fake_app.last_span_sampled).to eq(false)
              end
            end
          end
        end

        describe "tracecontext" do
          before do
            configure_otlp(['tracecontext'], [], sampling_ratio: 1)
          end

          it 'does parse tracecontext headers when a tracecontext extractor is configured' do
            middlewares.call(
              {
                'HTTP_TRACEPARENT' => "00-#{trace_id}-#{span_id}-01",
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'does not parse tracecontext headers when no tracecontext extractor is configured' do
            configure_otlp([], [])
            middlewares.call(
              { 'HTTP_TRACEPARENT' => "00-#{trace_id}-#{span_id}-01" }
            )
            expect(fake_app.parsed_trace_id).to eq(fake_app.last_trace_id)
            expect(fake_app.parsed_span_id).to eq(fake_app.last_span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          describe 'the behaviour when the sampling header is set' do
            context 'when accept_sampling_instruction is false' do
              it 'does not enforce sampling when the sampling header is set to 1' do
                configure_otlp(['tracecontext'], [], sampling_ratio: 0)
                middlewares.call(
                  { 'HTTP_TRACEPARENT' => "00-#{trace_id}-#{span_id}-01" }
                )
                expect(fake_app.last_span_sampled).to eq(false)
              end

              it 'does not skip sampling when the sampling header is set to 0' do
                middlewares.call(
                  { 'HTTP_TRACEPARENT' => "00-#{trace_id}-#{span_id}-00" }
                )
                expect(fake_app.last_span_sampled).to eq(true)
              end
            end
            context 'when accept_sampling_instruction is true' do
              it 'does force sampling when the sampling header is set to 1' do
                configure_otlp(['tracecontext'], [], sampling_ratio: 0, accept_sampling_instruction: true)
                middlewares.call(
                  { 'HTTP_TRACEPARENT' => "00-#{trace_id}-#{span_id}-01" }
                )
                expect(fake_app.last_span_sampled).to eq(true)
              end
              it 'does prevent sampling when the sampling header is set to 0' do
                configure_otlp(['tracecontext'], [], sampling_ratio: 1, accept_sampling_instruction: true)
                middlewares.call(
                  { 'HTTP_TRACEPARENT' => "00-#{trace_id}-#{span_id}-00" }
                )
                expect(fake_app.last_span_sampled).to eq(false)
              end
            end
          end
        end

        describe "jaeger" do
          before do
            configure_otlp(['jaeger'], [])
          end

          it 'does parse jaeger headers when a jaeger extractor is configured' do
            middlewares.call(
              {
                'HTTP_UBER_TRACE_ID' => "#{trace_id}:#{span_id}:0:1"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'does not parse jaeger headers with only trace_id and span_id fields when a jaeger extractor is configured' do
            middlewares.call(
              {
                'HTTP_UBER_TRACE_ID' => "#{trace_id}:#{span_id}"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(fake_app.last_trace_id)
            expect(fake_app.parsed_span_id).to eq(fake_app.last_span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'does not parse jaeger headers when no jaeger extractor is configured' do
            configure_otlp([], [])
            middlewares.call(
              {
                'HTTP_UBER_TRACE_ID' => "#{trace_id}:#{span_id}:0:1"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(fake_app.last_trace_id)
            expect(fake_app.parsed_span_id).to eq(fake_app.last_span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          describe 'the behaviour when the sampling header is set' do
            context 'when accept_sampling_instruction is false' do
              it 'does not enforce sampling when the sampling header is set to 1' do
                configure_otlp(['jaeger'], [], sampling_ratio: 0)
                middlewares.call(
                  { 'HTTP_UBER_TRACE_ID' => "#{trace_id}:#{span_id}:0:1" }
                )
                expect(fake_app.last_span_sampled).to eq(false)
              end
              it 'does not skip sampling when the sampling header is set to 0' do
                middlewares.call(
                  { 'HTTP_UBER_TRACE_ID' => "#{trace_id}:#{span_id}:0:0" }
                )
                expect(fake_app.last_span_sampled).to eq(true)
              end
            end
            context 'when accept_sampling_instruction is true' do
              it 'does force sampling when the sampling header is set to 1' do
                configure_otlp(['jaeger'], [], sampling_ratio: 0, accept_sampling_instruction: true)
                middlewares.call(
                  { 'HTTP_UBER_TRACE_ID' => "#{trace_id}:#{span_id}:0:1" }
                )
                expect(fake_app.last_span_sampled).to eq(true)
              end
              it 'does prevent sampling when the sampling header is set to 0' do
                configure_otlp(['jaeger'], [], sampling_ratio: 1, accept_sampling_instruction: true)
                middlewares.call(
                  { 'HTTP_UBER_TRACE_ID' => "#{trace_id}:#{span_id}:0:0" }
                )
                expect(fake_app.last_span_sampled).to eq(false)
              end
            end
          end

          describe 'baggage' do
            it 'does parse baggage headers when a jaeger extractor is configured' do
              middlewares.call(
                {
                  'HTTP_UBER_TRACE_ID' => "#{trace_id}:#{span_id}:0:1",
                  'HTTP_UBERCTX_FOO' => 'bar'
                }
              )
              expect(fake_app.parsed_baggage_values['foo']).to eq('bar')
            end

            it 'does not parse baggage headers when no tracing header exists' do
              middlewares.call(
                {
                  'HTTP_UBERCTX-FOO' => 'bar'
                }
              )
              expect(fake_app.parsed_baggage_values).to eq({})
            end

            it 'does not parse baggage headers when no jaeger extractor is configured' do
              configure_otlp([], [])
              middlewares.call(
                {
                  'HTTP_UBER_TRACE_ID' => "#{ trace_id }:#{ span_id }:0:1",
                  'HTTP_UBERCTX-FOO' => 'bar'
                }
              )
              expect(fake_app.parsed_baggage_values).to eq({})
            end
          end
        end

        describe "xray" do
          before do
            configure_otlp(['xray'], [])
          end

          it 'does parse xray headers when a xray extractor is configured' do
            middlewares.call(
              {
                'HTTP_X_AMZN_TRACE_ID' => "Root=1-#{trace_id[0...8]}-#{trace_id[8...]};Parent=#{span_id};Sampled=1"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'does parse xray headers without optional fields when a xray extractor is configured' do
            middlewares.call(
              {
                'HTTP_X_AMZN_TRACE_ID' => "Root=1-#{trace_id[0...8]}-#{trace_id[8...]};Parent=#{span_id}"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id)
            expect(fake_app.parsed_span_id).to eq(span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'does not parse xray headers when no xray extractor is configured' do
            configure_otlp([], [])
            middlewares.call(
              {
                'HTTP_X_AMZN_TRACE_ID' => "Root=1-#{trace_id[0...8]}-#{trace_id[8...]};Parent=#{span_id};Sampled=1"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(fake_app.last_trace_id)
            expect(fake_app.parsed_span_id).to eq(fake_app.last_span_id)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          describe 'the behaviour when the sampling header is set' do
            context 'when accept_sampling_instruction is false' do
              it 'does not enforce sampling when the sampling header is set to 1' do
                configure_otlp(['xray'], [], sampling_ratio: 0)
                middlewares.call(
                  { 'HTTP_X_AMZN_TRACE_ID' => "Root=1-#{trace_id[0...8]}-#{trace_id[8...]};Parent=#{span_id};Sampled=1" }
                )
                expect(fake_app.last_span_sampled).to eq(false)
              end
              it 'does not skip sampling when the sampling header is set to 0' do
                middlewares.call(
                  { 'HTTP_X_AMZN_TRACE_ID' => "Root=1-#{trace_id[0...8]}-#{trace_id[8...]};Parent=#{span_id};Sampled=0" }
                )
                expect(fake_app.last_span_sampled).to eq(true)
              end
            end
            context 'when accept_sampling_instruction is true' do
              it 'does force sampling when the sampling header is set to 1' do
                configure_otlp(['xray'], [], sampling_ratio: 0, accept_sampling_instruction: true)
                middlewares.call(
                  { 'HTTP_X_AMZN_TRACE_ID' => "Root=1-#{trace_id[0...8]}-#{trace_id[8...]};Parent=#{span_id};Sampled=1" }
                )
                expect(fake_app.last_span_sampled).to eq(true)
              end
              it 'does prevent sampling when the sampling header is set to 0' do
                configure_otlp(['xray'], [], sampling_ratio: 1, accept_sampling_instruction: true)
                middlewares.call(
                  { 'HTTP_X_AMZN_TRACE_ID' => "Root=1-#{trace_id[0...8]}-#{trace_id[8...]};Parent=#{span_id};Sampled=0" }
                )
                expect(fake_app.last_span_sampled).to eq(false)
              end
            end
          end
          describe 'baggage' do
            it 'does not parse baggage headers when a xray extractor is configured, as this is not supported in ruby opentelemetry' do
              middlewares.call(
                {
                  'HTTP_X_AMZN_TRACE_ID' => "Root=1-#{trace_id[0...8]}-#{trace_id[8...]};Parent=#{span_id};Sampled=1;foo=bar"
                }
              )
              expect(fake_app.parsed_baggage_values['segment']).to be_nil
            end
          end
        end

        describe "baggage" do
          before do
            configure_otlp(%w[baggage], [])
          end

          it 'parses the baggage header when the baggage header is present' do
            middlewares.call(
              {
                'HTTP_BAGGAGE' => 'foo=bar'
              }
            )
            expect(fake_app.parsed_baggage_values['foo']).to eq('bar')
          end

          it 'does not parse the baggage header when no baggage extractor is configured' do
            configure_otlp(%w[], [])
            middlewares.call(
              {
                'HTTP_BAGGAGE' => 'foo=bar'
              }
            )
            expect(fake_app.parsed_baggage_values['foo']).to be_nil
          end
        end

        describe 'handling multiple extractors' do
          #First Header of Propagation method is used for propagation; Second one is being ignored
          let(:trace_id_1) { SecureRandom.hex(16) }
          let(:span_id_1) { SecureRandom.hex(8) }
          let(:trace_id_2) { SecureRandom.hex(16) }
          let(:span_id_2) { SecureRandom.hex(8) }

          it 'uses the last configured extractor in the extractor config array jaeger' do
            configure_otlp(%w[baggage jaeger tracecontext], [])
            middlewares.call(
              {
                'HTTP_TRACEPARENT' => "00-#{trace_id_2}-#{span_id_2}-01",
                'HTTP_UBER_TRACE_ID' => "#{trace_id_1 }:#{ span_id_1 }:0:1"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id_2)
            expect(fake_app.parsed_span_id).to eq(span_id_2)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'prefers baggage over the jaeger baggage extraction' do
            configure_otlp(%w[baggage b3 jaeger], [])
            middlewares.call(
              {
                'HTTP_B3' =>  "#{trace_id_2}-#{span_id_2}-1",
                'HTTP_UBERCX_FOO2' => 'bar2',
                'HTTP_UBER_TRACE_ID' => "#{trace_id_1}:#{ span_id_1}:0:1",
                'HTTP_BAGGAGE' => 'foo1=bar1'
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id_1)
            expect(fake_app.parsed_span_id).to eq(span_id_1)
            expect(fake_app.last_span_sampled).to eq(true)
            expect(fake_app.parsed_baggage_values['foo1']).to eq('bar1')
            expect(fake_app.parsed_baggage_values['foo2']).to be_nil
          end

          it 'uses the last configured extractor in the extractor config array jaeger' do
            configure_otlp(%w[tracecontext jaeger], [])
            middlewares.call(
              {
                'HTTP_UBER_TRACE_ID' => "#{trace_id_1}:#{span_id_1}:0:1",
                'HTTP_TRACEPARENT' => "00-#{trace_id_2}-#{span_id_2}-01"
              }
            )
            expect(fake_app.parsed_trace_id).to eq(trace_id_1)
            expect(fake_app.parsed_span_id).to eq(span_id_1)
            expect(fake_app.last_span_sampled).to eq(true)
          end

          it 'honors the sampled flag of the last extractor' do
            configure_otlp(%w[tracecontext jaeger], [], accept_sampling_instruction: true)
            middlewares.call(
              {
                'HTTP_UBER_TRACE_ID' => "#{ trace_id_1 }:#{ span_id_1 }:0:1",
                'HTTP_TRACEPARENT' => "00-#{trace_id_2}-#{span_id_2}-00"
              }
            )
            expect(fake_app.last_span_sampled).to eq(true)
          end
        end
      end

      describe 'injectors behaviour in regards to the configuration' do
        describe 'b3multi' do
          it 'does inject the b3multi headers' do
            configure_otlp([], ['b3multi'])
            middlewares.call({})

            expect(WebMock).to have_requested(:get, "http://fake.net_http.request/").times(2)
            expect(WebMock).to have_requested(:get, "http://fake.http_client.request/").times(1)

            requests = WebMock::RequestRegistry.instance.requested_signatures.hash.keys

            requests.each do |req|
              expect(req.headers['X-B3-Sampled']).to eq(fake_app.last_span_sampled ? '1' : '0'), "Expected Request: '#{req}' to have sampled flag: '#{fake_app.last_span_sampled ? '1' : '0'}' in the X-B3-Sampled header."
              expect(req.headers['X-B3-Traceid']).to eq(fake_app.last_trace_id), "Expected Request: '#{req}' to have trace id: '#{fake_app.last_trace_id}' in the X-B3-TraceId header."
              expect(req.headers['X-B3-Spanid']).not_to be_nil, "Expected Request: '#{req}' to have the X-B3-SpanId header."
            end
          end
        end

        describe 'b3' do
          it 'does inject the b3 headers' do
            configure_otlp([], ['b3'])
            middlewares.call({})

            expect(WebMock).to have_requested(:get, "http://fake.net_http.request/").times(2)
            expect(WebMock).to have_requested(:get, "http://fake.http_client.request/").times(1)

            requests = WebMock::RequestRegistry.instance.requested_signatures.hash.keys

            requests.each do |req|
                expect(req.headers['B3']).not_to be_nil, "Expected Request: '#{req}' to have B3 header."
                trace, span, sampled = req.headers['B3'].split('-')
                expect(trace).to eq(fake_app.last_trace_id), "Expected Request: '#{req}' to have trace id: '#{fake_app.last_trace_id}' in the B3 header."
                expect(span).not_to be_nil , "Expected Request: '#{req}' to have span id not nil in the B3 header."
                expect(sampled).to eq(fake_app.last_span_sampled ? '1' : '0') , "Expected Request: '#{req}' to have sampled flag: '#{fake_app.last_span_sampled ? '1' : '0'}' in the B3 header."
            end
          end
        end

        describe 'tracecontext' do
          it 'does inject the tracecontext headers' do
            configure_otlp([], ['tracecontext'])
            middlewares.call({})

            expect(WebMock).to have_requested(:get, "http://fake.net_http.request/").times(2)
            expect(WebMock).to have_requested(:get, "http://fake.http_client.request/").times(1)

            requests = WebMock::RequestRegistry.instance.requested_signatures.hash.keys
            requests.each do |req|
              expect(req.headers['Traceparent']).not_to be_nil, "Expected Request: '#{req}' to have Traceparent header."
              version, trace, span, sampled = req.headers['Traceparent'].split('-')
              expect(trace).to eq(fake_app.last_trace_id), "Expected Request: '#{req}' to have trace id: '#{fake_app.last_trace_id}' in the Traceparent header."
              expect(span).not_to be_nil , "Expected Request: '#{req}' to have span id not nil in the Traceparent header."
              expect(sampled).to eq(fake_app.last_span_sampled ? '01' : '00') , "Expected Request: '#{req}' to have sampled flag: '#{fake_app.last_span_sampled ? '01' : '00'}' in the Traceparent header."
            end
          end
        end

        describe 'jaeger' do
          it 'does inject the jaeger headers with baggage' do
            configure_otlp([], ['jaeger'])
            middlewares.call({})

            expect(WebMock).to have_requested(:get, "http://fake.net_http.request/").times(2)
            expect(WebMock).to have_requested(:get, "http://fake.http_client.request/").times(1)

            requests = WebMock::RequestRegistry.instance.requested_signatures.hash.keys
            requests.each do |req|
              expect(req.headers['Uber-Trace-Id']).not_to be_nil, "Expected Request: '#{req}' to have Uber-Trace-Id header."
              trace, span, flags, sampled = req.headers['Uber-Trace-Id'].split(':')
              expect(trace).to eq(fake_app.last_trace_id), "Expected Request: '#{req}' to have trace id: '#{fake_app.last_trace_id}' in the Uber-Trace-Id header."
              expect(span).not_to be_nil , "Expected Request: '#{req}' to have span id not nil in the Uber-Trace-Id header."
              expect(sampled).to eq(fake_app.last_span_sampled ? '1' : '0') , "Expected Request: '#{req}' to have sampled flag: '#{fake_app.last_span_sampled ? '1' : '0'}' in the Uber-Trace-Id header."
              expect(req.headers['Uberctx-Test']).to eq('bommel'), "Expected Request: '#{req}' to have the Uberctx-Test header with value 'bommel'."
            end
          end
        end

        describe 'xray' do
          it 'does inject the xray headers' do
            configure_otlp([], ['xray'])
            middlewares.call({})

            expect(WebMock).to have_requested(:get, "http://fake.net_http.request/").times(2)
            expect(WebMock).to have_requested(:get, "http://fake.http_client.request/").times(1)

            requests = WebMock::RequestRegistry.instance.requested_signatures.hash.keys
            requests.each do |req|
              expect(req.headers['X-Amzn-Trace-Id']).not_to be_nil, "Expected Request: '#{req}' to have X-Amzn-Trace-Id header."
              root, parent, sampled = req.headers['X-Amzn-Trace-Id'].split(';')
              expect(root).to eq("Root=1-#{fake_app.last_trace_id[0...8]}-#{fake_app.last_trace_id[8...]}"), "Expected Request: '#{req}' to have trace id: '#{fake_app.last_trace_id}' in the X-Amzn-Trace-Id header."
              expect(parent.split('=')[1]).not_to be_nil, "Expected Request: '#{req}' to have span id in the X-Amzn-Trace-Id header."
              expect(sampled).to eq("Sampled=#{fake_app.last_span_sampled ? '1' : '0'}") , "Expected Request: '#{req}' to have sampled flag: '#{fake_app.last_span_sampled ? '1' : '0'}' in the X-Amzn-Trace-Id header."
            end
          end
        end

        describe 'baggage' do
          it 'does inject the baggage headers' do
            configure_otlp([], ['baggage'])
            middlewares.call({})
            expected_headers = {
              'Baggage' => 'test=bommel'
            }
            expect(WebMock).to have_requested(:get, "http://fake.net_http.request/").with(headers: expected_headers).times(2)
            expect(WebMock).to have_requested(:get, "http://fake.http_client.request/").with(headers: expected_headers).times(1)
          end
        end

        describe 'none' do
          it 'does not inject headers when no injector is configured' do
            configure_otlp([], [])
            middlewares.call({})
            expected_headers = {
              'X-B3-TraceId' => fake_app.last_trace_id
            }
            expect(WebMock).to_not have_requested(:get, "http://fake.net_http.request/").with(headers: expected_headers)
            expect(WebMock).to_not have_requested(:get, "http://fake.http_client.request/").with(headers: expected_headers)
          end

          it 'does not inject headers when the none injector is configured' do
            configure_otlp([], ['none'])
            middlewares.call({})
            expected_headers = {
              'X-B3-TraceId' => fake_app.last_trace_id
            }
            expect(WebMock).to_not have_requested(:get, "http://fake.net_http.request/").with(headers: expected_headers)
            expect(WebMock).to_not have_requested(:get, "http://fake.http_client.request/").with(headers: expected_headers)
          end
        end

        describe 'multiple injectors' do
          it 'injects the headers of all configured injectors' do
            configure_otlp([], %w[b3multi b3 jaeger baggage])
            middlewares.call({})

            expect(WebMock).to have_requested(:get, "http://fake.net_http.request/").times(2)
            expect(WebMock).to have_requested(:get, "http://fake.http_client.request/").times(1)

            requests = WebMock::RequestRegistry.instance.requested_signatures.hash.keys

            requests = WebMock::RequestRegistry.instance.requested_signatures.hash.keys
            requests.each do |req|
              # B3 Multi
              expect(req.headers['X-B3-Spanid']).not_to be_nil, "Expected Request: '#{req}' to have X-B3-Spanid header."
              expect(req.headers['X-B3-Traceid']).to eq(fake_app.last_trace_id), "Expected Request: '#{req}' to have trace id: '#{fake_app.last_trace_id}' in the X-B3-TraceId header."
              expect(req.headers['X-B3-Sampled']).to eq(fake_app.last_span_sampled ? '1' : '0') , "Expected Request: '#{req}' to have sampled flag: '#{fake_app.last_span_sampled ? '1' : '0'}' in the X-B3-Sampled header."
              # B3
              expect(req.headers['B3']).not_to be_nil, "Expected Request: '#{req}' to have B3 header."
              trace, span, sampled = req.headers['B3'].split('-')
              expect(trace).to eq(fake_app.last_trace_id), "Expected Request: '#{req}' to have trace id: '#{fake_app.last_trace_id}' in the B3 header."
              expect(span).not_to be_nil , "Expected Request: '#{req}' to have span id not nil in the B3 header."
              expect(sampled).to eq(fake_app.last_span_sampled ? '1' : '0') , "Expected Request: '#{req}' to have sampled flag: '#{fake_app.last_span_sampled ? '1' : '0'}' in the B3 header."
              # Jaeger
              expect(req.headers['Uber-Trace-Id']).not_to be_nil, "Expected Request: '#{req}' to have Uber-Trace-Id header."
              trace, span, flags, sampled = req.headers['Uber-Trace-Id'].split(':')
              expect(trace).to eq(fake_app.last_trace_id), "Expected Request: '#{req}' to have trace id: '#{fake_app.last_trace_id}' in the Uber-Trace-Id header."
              expect(span).not_to be_nil , "Expected Request: '#{req}' to have span id not nil in the Uber-Trace-Id header."
              expect(sampled).to eq(fake_app.last_span_sampled ? '1' : '0') , "Expected Request: '#{req}' to have sampled flag: '#{fake_app.last_span_sampled ? '1' : '0'}' in the Uber-Trace-Id header."
              expect(req.headers['Uberctx-Test']).to eq('bommel'), "Expected Request: '#{req}' to have Uberctx-Test header with value 'bommel'."
              # Baggage
              expect(req.headers['Baggage']).to eq('test=bommel'), "Expected Request: '#{req}' to have Baggage header with value 'foo=bommel'."
            end
          end
        end
      end
    end
  end
end
