module CloudFoundry
  module Middleware
    class BelowMinCliWarning
      def initialize(app)
        @app = app
        @min_cli_version = Gem::Version.new(VCAP::CloudController::Config.config.get(:info, :min_cli_version))
      end

      def call(env)
        status, headers, body = @app.call(env)

        included_endpoints = %w[/v3/spaces /v3/organizations /v2/spaces /v2/organizations]

        if included_endpoints.any? { |ep| env['REQUEST_PATH'].include?(ep) } && is_below_min_cli_version?(env['HTTP_USER_AGENT'])
          # Ensure existing warnings are appended by ',' (unicode %2C)
          new_warning = env['X-Cf-Warnings'].nil? ? escaped_warning : "#{env['X-Cf-Warnings']}%2C#{escaped_warning}"
          headers['X-Cf-Warnings'] = new_warning
        end

        [status, headers, body]
      end

      def escaped_warning
        CGI.escape("\u{1F6A8} [WARNING] Outdated CF CLI version - please upgrade: https://github.com/cloudfoundry/cli/releases/latest \u{1F6A8}\n")
      end

      def is_below_min_cli_version?(user_agent_string)
        regex = %r{
            [cC][fF]      # match 'cf', case insensitive
            [^/]*        # match any characters that are not '/'
            /            # match '/' character
            (\d+\.\d+\.\d+)  # capture the version number (expecting 3 groups of digits separated by '.')
            (?:\+|\s)     # match '+' character or a whitespace, non-capturing group
          }x

        match = user_agent_string.match(regex)
        return false if match.nil?

        current_version = Gem::Version.new(match[1])

        current_version < @min_cli_version
      rescue StandardError => e
        logger.warn("Warning: An error occurred while checking user agent version: #{e.message}")
        false
      end

      private

      def logger
        @logger = Steno.logger('cc.deprecated_cf_cli_warning')
      end
    end
  end
end
