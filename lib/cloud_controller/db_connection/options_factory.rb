require 'cloud_controller/db_connection/mysql_options_factory'
require 'cloud_controller/db_connection/postgres_options_factory'

module VCAP::CloudController
  module DbConnection
    class UnknownSchemeError < StandardError
      def initialize(scheme)
        @scheme = scheme
      end

      def to_s
        "Unknown database scheme provided: '#{@scheme}'"
      end
    end

    class OptionsFactory
      class << self
        def build(opts)
          base_options(opts).
            merge(adapter_options(opts)).
            merge(opts[:database]).
            compact
        end

        private

        FACTORIES = {
          'mysql' => MysqlOptionsFactory,
          'mysql2' => MysqlOptionsFactory,
          'postgres' => PostgresOptionsFactory,
        }.freeze

        def base_options(opts)
          {
            connection_validation_timeout: opts[:connection_validation_timeout],
            log_db_queries: opts[:log_db_queries],
            log_level: opts[:log_level],
            max_connections: opts[:max_connections],
            pool_timeout: opts[:pool_timeout],
            read_timeout: opts[:read_timeout],
            sql_mode: [:strict_trans_tables, :strict_all_tables, :no_zero_in_date],
          }
        end

        def adapter_options(opts)
          adapter = opts[:database][:adapter]
          factory_for(adapter).build(opts)
        end

        def factory_for(adapter)
          FACTORIES[adapter] or raise UnknownSchemeError.new(adapter)
        end
      end
    end
  end
end
