require 'vcap/config'

module VCAP::CloudController
  module ConfigSchemas
    module Vms
      class RotateDatabaseKeySchema < VCAP::Config
        define_schema do
          {
            logging: {
              level: String, # debug, info, etc.
              file: String, # Log file to use
              syslog: String, # Name to associate with syslog messages (should start with 'vcap.')
              stdout_sink_enabled: bool
            },

            pid_filename: String, # Pid filename to use

            optional(:max_migration_duration_in_minutes) => Integer,
            db: {
              optional(:database) => Hash, # db connection hash for sequel\
              max_connections: Integer, # max connections in the connection pool
              pool_timeout: Integer, # timeout before raising an error when connection can't be established to the db
              log_level: String, # debug, info, etc.
              log_db_queries: bool,
              ssl_verify_hostname: bool,
              connection_validation_timeout: Integer,
              optional(:ca_cert_path) => String
            },

            index: Integer, # Component index (cc-0, cc-1, etc)
            name: String, # Component name (api_z1, api_z2)

            default_app_ssh_access: bool,

            db_encryption_key: enum(String, NilClass),

            optional(:database_encryption) => {
              keys: Hash,
              current_key_label: String,
              optional(:pbkdf2_hmac_iterations) => Integer
            }
          }
        end

        class << self
          def configure_components(config); end
        end
      end
    end
  end
end
