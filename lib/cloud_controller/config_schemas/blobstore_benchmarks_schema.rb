require 'vcap/config'

module VCAP::CloudController
  module ConfigSchemas
    class BlobstoreBenchmarksSchema < VCAP::Config
      # rubocop:disable Metrics/BlockLength
      define_schema do
        blobstore_section = {
          blobstore_type: String,
          optional(:blobstore_provider) => String,

          optional(:connection_config) => Hash,
          optional(:fog_connection) => Hash,

          fog_aws_storage_options: Hash,
          fog_gcp_storage_options: Hash,

          optional(:resource_directory_key) => String,
          optional(:buildpack_directory_key) => String,
          optional(:app_package_directory_key) => String,
          optional(:droplet_directory_key) => String,

          optional(:maximum_size) => Integer,
          optional(:minimum_size) => Integer,
          optional(:max_package_size) => Integer,
          optional(:max_valid_packages_stored) => Integer,
          optional(:max_staged_droplets_stored) => Integer
        }

        {
          optional(:logging) => {
            optional(:level) => String,
            optional(:file) => String,
            optional(:syslog) => String,
            optional(:stdout_sink_enabled) => bool
          },

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
          optional(:storage_cli_config_file_resource_pool) => String,
          optional(:storage_cli_config_file_buildpacks) => String,
          optional(:storage_cli_config_file_packages) => String,
          optional(:storage_cli_config_file_droplets) => String,

          db_encryption_key: enum(String, NilClass),

          optional(:database_encryption) => {
            keys: Hash,
            current_key_label: String,
            optional(:pbkdf2_hmac_iterations) => Integer
          },

          resource_pool: blobstore_section,
          buildpacks: blobstore_section,
          packages: blobstore_section,
          droplets: blobstore_section,

          pid_filename: String,
          index: Integer, # Component index (cc-0, cc-1, etc)
          name: String, # Component name (api_z1, api_z2)
          default_app_ssh_access: bool
        }
      end
      # rubocop:enable Metrics/BlockLength

      class << self
        def configure_components(config)
          ResourcePool.instance = ResourcePool.new(config)
        end
      end
    end
  end
end
