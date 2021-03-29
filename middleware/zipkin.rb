module CloudFoundry
  module Middleware
    class Zipkin
      def initialize(app)
        @app = app
      end

      def call(env)
        return call_app(env) if !(env['HTTP_X_B3_TRACEID'] && env['HTTP_X_B3_SPANID'])

        env['b3.trace_id'], env['b3.span_id'] = external_b3_ids(env)

        ::VCAP::Request.b3_trace_id = env['b3.trace_id']
        ::VCAP::Request.b3_span_id = env['b3.span_id']

        zipkin_headers = {
          'X-B3-TraceId' => env['HTTP_X_B3_TRACEID'],
          'X-B3-SpanId'  => env['HTTP_X_B3_SPANID']
        }

        status, headers, body = @app.call(env)

        ::VCAP::Request.b3_trace_id = nil
        ::VCAP::Request.b3_span_id = nil

        [status, headers.merge(zipkin_headers), body]
      end

      def call_app(env)
        @app.call(env)
      end

      def external_b3_ids(env)
        trace_id = env['HTTP_X_B3_TRACEID']
        span_id = env ['HTTP_X_B3_SPANID']

        [trace_id, span_id]
      end
    end
  end
end
