require 'opentelemetry/sdk'

module CloudFoundry
  module Middleware
    class OpenTelemetryFirstMiddleware
      attr_reader :initial_span, :initial_baggage

      def initialize(app)
        @app = app
        @tracer = OpenTelemetry.tracer_provider.tracer('CC_NG_API', '1.0')
      end

      def call(env)
        # Extract context from request headers
        tracing_context = OpenTelemetry.propagation.extract(
          env,
          getter: OpenTelemetry::Common::Propagation.rack_env_getter
        )

        # Span name SHOULD be set to route:
        span_name = env['PATH_INFO'] || 'unknown'

        # Use the extracted/adopted context
        OpenTelemetry::Context.with_current(tracing_context) do
          # Span kind MUST be `:server` for a HTTP server span
          @tracer.in_span(
            span_name,
            attributes: {
              'http.request.method' => check_header_value(env['REQUEST_METHOD']),
              'url.path' => check_header_value(env['PATH_INFO']),
              'url.scheme' => check_header_value(env['rack.url_scheme']),
              'url.query' => check_header_value(env['QUERY_STRING']),
              'url.full' => check_header_value(env['REQUEST_URI']),
              'http.host' => check_header_value(env['HTTP_HOST']),
              'user_agent.original' => check_header_value(env['HTTP_USER_AGENT']),
              'http.request.header.connection' => check_header_value(env['HTTP_CONNECTION']),
              'http.request.header.version' => check_header_value(env['HTTP_VERSION']),
              'http.request.header.x_real_ip' => check_header_value(env['HTTP_X_REAL_IP']),
              'http.request.header.x_forwared_for' => check_header_value(env['HTTP_X_FORWARDED_FOR']),
              'http.request.header.accept' => check_header_value(env['HTTP_ACCEPT']),
              'http.request.header.accept_encoding' => check_header_value(env['HTTP_ACCEPT_ENCODING']),
              'http.request.body.size' => check_header_value(env['CONTENT_LENGTH'])
            },
            kind: :server
          ) do |span|
            middleware_pre_app_span = @tracer.start_span('middleware-pre-app')
            OpenTelemetry::Trace.with_span(middleware_pre_app_span) do
              @status, @headers, @body = @app.call(env)
            rescue Exception => e # rubocop:disable Lint/RescueException
              span.record_exception(e)
              span.status = OpenTelemetry::Trace::Status.error("Exception: #{e.class} - #{e.message}")
              raise e
            end
            # Set return attributes
            span.set_attribute('http.response.status_code', @status)
            span.set_attribute('http.response.body.size', @body.respond_to?(:bytesize) ? @body.bytesize : 0)
          end

          [@status, @headers, @body]
        end
      end

      def check_header_value(header_value)
        return '' unless header_value.is_a? String

        return '' if header_value.empty?

        return '' if header_value.bytesize > 100_000

        header_value
      end
    end

    class OpenTelemetryLastMiddleware
      def initialize(app)
        @app = app
        @tracer = OpenTelemetry.tracer_provider.tracer('CC_NG', '1.0')
      end

      def call(env)
        # Close the span that measures middlewares-pre-app
        OpenTelemetry::Trace.current_span.finish
        # Measure application runtime in a seperate span
        @tracer.in_span('application') do |_span|
          @status, @headers, @body = @app.call(env)
        end
        [@status, @headers, @body]
      end
    end
  end
end
