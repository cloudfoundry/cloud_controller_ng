module Rack
  module Test
    class Session
      private

      alias_method :orig_env_for, :env_for
      def env_for(path, env)
        new_env = orig_env_for(path, env)
        uri = URI.parse(path)
        if uri.query
          new_env["QUERY_STRING"] = "#{uri.query}&#{new_env['QUERY_STRING']}"
        end
        new_env
      end
    end
  end
end
