require 'vcap/config'

module VCAP::CloudController
  module ConfigSchemas
    class MigrateSchema < VCAP::Config
      define_schema do
        {
          optional(:max_migration_duration_in_minutes) => Integer,
          optional(:max_migration_statement_runtime_in_seconds) => Integer,
          optional(:migration_psql_concurrent_statement_timeout_in_seconds) => Integer,
          optional(:migration_psql_worker_memory_kb) => Integer,
          optional(:skip_bigint_id_migration) => bool,

          db: {
            optional(:database) => Hash, # db connection hash for sequel
            :max_connections => Integer, # max connections in the connection pool
            :pool_timeout => Integer, # timeout before raising an error when connection can't be established to the db
            :log_level => String, # debug, info, etc.
            :connection_validation_timeout => Integer,
            optional(:log_db_queries) => bool,
            optional(:ssl_verify_hostname) => bool,
            optional(:ca_cert_path) => String,
            optional(:enable_paginate_window) => bool
          },

          db_encryption_key: enum(String, NilClass),

          optional(:database_encryption) => {
            keys: Hash,
            current_key_label: String,
            optional(:pbkdf2_hmac_iterations) => Integer
          },

          logging: {
            level: String, # debug, info, etc.
            file: String, # Log file to use
            syslog: String, # Name to associate with syslog messages (should start with 'vcap.')
            optional(:stdout_sink_enabled) => bool
          }
        }
      end

      class << self
        def configure_components(_); end
      end
    end
  end
end
