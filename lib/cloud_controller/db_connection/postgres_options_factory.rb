module VCAP::CloudController
  module DbConnection
    class PostgresOptionsFactory
      SQL_CONNECTION_PARAMETERS = %i[statement_timeout idle_in_transaction_session_timeout].freeze
      LIBPQ_CONNECTION_PARAMETERS = %i[keepalives keepalives_idle keepalives_interval keepalives_count].freeze

      def self.build(opts)
        options = {}

        if opts[:ca_cert_path]
          options[:sslrootcert] = opts[:ca_cert_path]
          options[:sslmode] = opts[:ssl_verify_hostname] ? 'verify-full' : 'verify-ca'
        end

        psql_opts = opts[:psql] || {}
        sql_params = psql_opts.slice(*SQL_CONNECTION_PARAMETERS).compact
        connect_sqls = ["SET time zone 'UTC'"]
        sql_params.each do |key, value|
          connect_sqls << "SET #{key} TO '#{value}'"
        end
        options[:connect_sqls] = connect_sqls

        libpq_params = psql_opts.slice(*LIBPQ_CONNECTION_PARAMETERS).compact
        options.merge!(libpq_params)

        options
      end
    end
  end
end
