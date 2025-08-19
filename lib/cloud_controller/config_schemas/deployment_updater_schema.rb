require 'vcap/config'

module VCAP::CloudController
  module ConfigSchemas
    class DeploymentUpdaterSchema < VCAP::Config
      # rubocop:disable Metrics/BlockLength
      define_schema do
        {

          logging: {
            level: String, # debug, info, etc.
            file: String, # Log file to use
            syslog: String # Name to associate with syslog messages (should start with 'vcap.')
          },

          pid_filename: String, # Pid filename to use
          readiness_port: {
            deployment_updater: Integer
          },
          optional(:max_migration_duration_in_minutes) => Integer,
          db: {
            optional(:database) => Hash, # db connection hash for sequel
            max_connections: Integer, # max connections in the connection pool
            pool_timeout: Integer, # timeout before raising an error when connection can't be established to the db
            log_level: String, # debug, info, etc.
            log_db_queries: bool,
            ssl_verify_hostname: bool,
            connection_validation_timeout: Integer,
            optional(:ca_cert_path) => String,
            optional(:connection_expiration_timeout) => Integer,
            optional(:connection_expiration_random_delay) => Integer
          },

          index: Integer, # Component index (cc-0, cc-1, etc)
          name: String, # Component name (api_z1, api_z2)

          external_port: Integer,
          tls_port: Integer,
          internal_service_hostname: String,
          external_domain: String,
          external_protocol: String,

          default_health_check_timeout: Integer,
          maximum_health_check_timeout: Integer,

          db_encryption_key: enum(String, NilClass),

          optional(:database_encryption) => {
            keys: Hash,
            current_key_label: String,
            optional(:pbkdf2_hmac_iterations) => Integer
          },

          cpu_weight_min_memory: Integer,
          cpu_weight_max_memory: Integer,
          default_app_memory: Integer,
          default_app_disk_in_mb: Integer,
          maximum_app_disk_in_mb: Integer,
          instance_file_descriptor_limit: Integer,
          additional_allowed_process_users: Array,

          deployment_updater: {
            update_frequency_in_seconds: Integer,
            optional(:lock_key) => String,
            optional(:lock_owner) => String
          },

          optional(:locket) => {
            host: String,
            port: Integer,
            ca_file: String,
            cert_file: String,
            key_file: String
          },

          staging: {
            auth: {
              user: String,
              password: String
            },
            timeout_in_seconds: Integer
          },

          diego: {
            bbs: {
              url: String,
              ca_file: String,
              cert_file: String,
              key_file: String,
              connect_timeout: Integer,
              send_timeout: Integer,
              receive_timeout: Integer
            },
            cc_uploader_url: String,
            file_server_url: String,
            lifecycle_bundles: Hash,
            droplet_destinations: Hash,
            pid_limit: Integer,
            use_privileged_containers_for_running: bool,
            use_privileged_containers_for_staging: bool,
            optional(:temporary_oci_buildpack_mode) => enum('oci-phase-1', NilClass),
            enable_declarative_asset_downloads: bool
          },

          app_log_revision: bool,

          resource_pool: {
            maximum_size: Integer,
            minimum_size: Integer,
            resource_directory_key: String,
            fog_connection: Hash,
            optional(:connection_config) => Hash,
            fog_aws_storage_options: Hash,
            fog_gcp_storage_options: Hash
          },

          buildpacks: {
            buildpack_directory_key: String,
            fog_connection: Hash,
            optional(:connection_config) => Hash,
            fog_aws_storage_options: Hash,
            fog_gcp_storage_options: Hash
          },

          packages: {
            max_package_size: Integer,
            app_package_directory_key: String,
            fog_connection: Hash,
            optional(:connection_config) => Hash,
            fog_aws_storage_options: Hash,
            fog_gcp_storage_options: Hash
          },

          droplets: {
            droplet_directory_key: String,
            fog_connection: Hash,
            optional(:connection_config) => Hash,
            fog_aws_storage_options: Hash,
            fog_gcp_storage_options: Hash
          },

          stacks_file: String,

          skip_cert_verify: bool,

          optional(:credhub_api) => {
            internal_url: String,
            ca_cert_path: String
          },

          credential_references: {
            interpolate_service_bindings: bool
          },

          optional(:routing_api) => {
            url: String,
            routing_client_name: String,
            routing_client_secret: String
          },

          statsd_host: String,
          statsd_port: Integer,
          optional(:enable_statsd_metrics) => bool,

          max_labels_per_resource: Integer,
          max_annotations_per_resource: Integer,
          custom_metric_tag_prefix_list: Array,

          optional(:feature_flag_overrides) => Hash
        }
      end
      # rubocop:enable Metrics/BlockLength

      class << self
        def configure_components(config); end
      end
    end
  end
end
