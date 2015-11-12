require 'securerandom'
require 'active_support/core_ext/string/access'

module CloudFoundry
  module Middleware
    class VcapRequestId
      def initialize(app)
        @app = app
      end

      def call(env)
        env['cf.request_id'] = external_request_id(env) || internal_request_id

        status, headers, body = @app.call(env)

        headers['X-VCAP-Request-ID'] = env['cf.request_id']
        [status, headers, body]
      end

      private

      def external_request_id(env)
        request_id = env['HTTP_X_VCAP_REQUEST_ID'].presence || env['HTTP_X_REQUEST_ID'].presence
        if request_id
          "#{request_id.gsub(/[^\w\-]/, '').first(255)}::#{SecureRandom.uuid}"
        end
      end

      def internal_request_id
        SecureRandom.uuid
      end
    end
  end
end
