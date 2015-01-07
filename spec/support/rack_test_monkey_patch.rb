module Rack
  module Test
    class Session
      private

      alias_method :orig_env_for, :env_for
      def env_for(path, env)
        params = env[:params]
        new_env = orig_env_for(path, env)

        if env[:method] == 'GET'
          # merge :params with the query string
          uri = URI.parse(path)

          if params
            params = parse_nested_query(params) if params.is_a?(String)
            uri.query = [uri.query, build_nested_query(params)].compact.join('&')
          end
          new_env['QUERY_STRING'] = uri.query
        end

        new_env
      end
    end
  end
end
