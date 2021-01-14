module VCAP::CloudController
  class DatabasePartsParser
    class << self
      def database_parts_from_connection(connection_string)
        uri = URI.parse(connection_string)
        {
          adapter: uri.scheme,
          host: uri.host,
          port: uri.port,
          user: uri.user,
          password: uri.password && CGI.unescape(uri.password),
          database: uri.path.sub(%r{^/}, ''),
        }
      end

      def connection_from_database_parts(config)
        parts = [config[:adapter], '://']
        if config[:user]
          parts << config[:user]
          if config[:password]
            parts << ':'
            parts << CGI.escape(config[:password])
          end
          parts << '@'
        end
        parts << config[:host]
        if config[:port]
          parts << ':'
          parts << config[:port]
        end
        parts << '/'
        parts << config[:database]
        parts.join
      end
    end
  end
end
