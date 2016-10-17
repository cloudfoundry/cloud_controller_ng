require 'newrelic_rpm'

module CloudFoundry
  module Middleware
    class NewRelicCustomAttributes
      def initialize(app)
        @app = app
      end

      def call(env)
        NewRelic::Agent.add_custom_attributes vcap_request_id: env['cf.request_id']
        status, headers, body = @app.call(env)

        [status, headers, body]
      end
    end
  end
end
