module VCAP::CloudController
  module DbConnection
    class Finalizer
      def self.finalize(db_connection, connection_options, logger)
        db_connection.extension(:connection_validator)

        if connection_options[:log_db_queries]
          db_connection.logger = logger
          db_connection.sql_log_level = connection_options[:log_level]
        end

        if connection_options[:connection_validation_timeout]
          db_connection.pool.connection_validation_timeout = connection_options[:connection_validation_timeout]
        end

        if db_connection.database_type == :mysql
          db_connection.default_collate = 'utf8_bin'
        end

        db_connection
      end
    end
  end
end
