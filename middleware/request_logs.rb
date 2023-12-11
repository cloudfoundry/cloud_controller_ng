require 'opentelemetry/sdk'

module CloudFoundry
  module Middleware
    class RequestLogs
      def initialize(app, request_logs)
        @request_logs = request_logs
        @app = app
        @MyAppTracer = OpenTelemetry.tracer_provider.tracer('CC_API')
      end

      def call(env)
        request_id = env['cf.request_id']
        @request_logs.start_request(request_id, env)

        status, headers, body = @MyAppTracer.in_span("Request") do |span|
          span.add_attributes({
                            "cc.path" => env['PATH_INFO'],
                            "cc.request_id" => request_id
                          })
           @app.call(env)
        end

        @request_logs.complete_request(request_id, status)
        [status, headers, body]
      end
    end
  end
end
