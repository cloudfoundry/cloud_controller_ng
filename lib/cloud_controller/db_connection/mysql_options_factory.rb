module VCAP::CloudController
  module DbConnection
    class MysqlOptionsFactory
      SUPPORTED_SSL_MODES = %i[disabled required].freeze

      def self.build(opts)
        options = {
          charset: 'utf8'
        }

        options[:after_connect] = proc do |connection|
          connection.query("SET time_zone = '+0:00'")
        end

        if opts[:ca_cert_path]
          options[:sslca] = opts[:ca_cert_path]
          if opts[:ssl_verify_hostname]
            # https://github.com/brianmario/mysql2/issues/879
            options[:sslverify] = true
          end
        elsif opts[:ssl_mode]
          # No CA configured: allow operators to pin an explicit ssl_mode instead
          # of relying on the client library default.
          ssl_mode = opts[:ssl_mode].to_sym
          unless SUPPORTED_SSL_MODES.include?(ssl_mode)
            raise ArgumentError.new("Unsupported ccdb.ssl_mode '#{opts[:ssl_mode]}' for mysql; supported values: #{SUPPORTED_SSL_MODES.join(', ')}")
          end

          options[:ssl_mode] = ssl_mode
        end

        options
      end
    end
  end
end
