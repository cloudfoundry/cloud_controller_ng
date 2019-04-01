module VCAP::CloudController
  module DbConnection
    class PostgresOptionsFactory
      def self.build(opts)
        options = {}

        if opts[:ca_cert_path]
          options[:sslrootcert] = opts[:ca_cert_path]
          options[:sslmode] = opts[:ssl_verify_hostname] ? 'verify-full' : 'verify-ca'
        end

        options[:after_connect] = proc do |connection|
          connection.exec("SET time zone 'UTC'")
        end

        options
      end
    end
  end
end
