require 'vcap/config'

module VCAP::CloudController
  module ConfigSchemas
    class MigrateSchema < VCAP::Config
      define_schema do
        {
          db: {
            optional(:database) => String, # db connection string for sequel
            :max_connections => Integer, # max connections in the connection pool
            :pool_timeout => Integer, # timeout before raising an error when connection can't be established to the db
            :log_level => String, # debug, info, etc.
            optional(:ssl_verify_hostname) => bool,
            optional(:ca_cert_path) => String,
          },

          db_encryption_key: String,

          optional(:database_encryption_keys) => {
              keys: Hash,
              current_key_label: String
          },

          logging: {
            level: String, # debug, info, etc.
            file: String, # Log file to use
            syslog: String, # Name to associate with syslog messages (should start with 'vcap.')
          },
        }
      end

      class << self
        def configure_components(_); end
      end
    end
  end
end
