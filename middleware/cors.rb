module CloudFoundry
  module Middleware
    class Cors
      CORS_VARY_HEADER = ['Origin'.freeze].freeze

      def initialize(app, allowed_cors_domains=[])
        @app                  = app
        @allowed_cors_domains = allowed_cors_domains.map { |d| /^#{Regexp.quote(d).gsub('\*', '.*?')}$/ }
      end

      def call(env)
        return call_app(env) unless env['HTTP_ORIGIN']
        return call_app(env) unless @allowed_cors_domains.any? { |d| d =~ env['HTTP_ORIGIN'] }

        cors_headers = {
          'Access-Control-Allow-Origin'      => env['HTTP_ORIGIN'],
          'Access-Control-Allow-Credentials' => 'true',
          'Access-Control-Expose-Headers'    => "x-cf-warnings,x-app-staging-log,#{::VCAP::Request::HEADER_NAME.downcase},location,range"
        }

        preflight_headers = cors_headers.merge('Vary' => CORS_VARY_HEADER.join(','))
        if env['REQUEST_METHOD'] == 'OPTIONS'
          return call_app(env) unless %w(get put delete post).include?(env['HTTP_ACCESS_CONTROL_REQUEST_METHOD'].to_s.downcase)

          preflight_headers.merge!({
            'Content-Type' => 'text/plain',
            'Access-Control-Allow-Methods' => 'GET,PUT,POST,DELETE',
            'Access-Control-Max-Age'       => '900',
            'Access-Control-Allow-Headers' => Set.new(['origin', 'content-type', 'authorization']).
              merge(env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS'].to_s.split(',').map(&:strip).map(&:downcase)).to_a.join(',')
          })
        end

        return [200, preflight_headers, ''] if env['REQUEST_METHOD'] == 'OPTIONS'

        status, headers, body = call_app(env)

        headers.merge!(cors_headers)
        headers['Vary'] = merge_vary_headers(headers['Vary'], CORS_VARY_HEADER)

        [status, headers.merge(cors_headers), body]
      end

      private

      def call_app(env)
        @app.call(env)
      end

      def merge_vary_headers(current, additional)
        current_array = current ? current.split(/,\s*/) : []
        (current_array + additional).flatten.uniq.join(',')
      end
    end
  end
end
