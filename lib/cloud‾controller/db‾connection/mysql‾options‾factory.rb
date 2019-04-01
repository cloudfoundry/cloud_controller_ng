module VCAP::CloudController
  module DbConnection
    class MysqlOptionsFactory
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
            options[:sslmode] = :verify_identity
            # Unclear why this second line is necessary:
            # https://github.com/brianmario/mysql2/issues/879
            options[:sslverify] = true
          else
            options[:sslmode] = :verify_ca
          end
        end

        options
      end
    end
  end
end
