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
        ::VCAP::Request.current_id = env['cf.request_id']
        ::VCAP::Request.api_version = api_version_from_path(env)

        status, headers, body = @app.call(env)

        ::VCAP::Request.current_id = nil
        ::VCAP::Request.api_version = nil
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

      def api_version_from_path(env)
        path_info = env['PATH_INFO']
        if path_info
          version = path_info[1..2]
          return version if [VCAP::Request::API_VERSION_V2, VCAP::Request::API_VERSION_V3].include?(version)
        end
      end
    end
  end
end
